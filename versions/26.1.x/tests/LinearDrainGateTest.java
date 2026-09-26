package net.linear;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;

import net.minecraft.SharedConstants;
import net.minecraft.server.Bootstrap;
import net.minecraft.world.level.ChunkPos;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Window gate on the per-tick flush drain (Team A, A-P1).
 *
 * <p>Assumes A-I1's gate in {@code flushAllDirty(boolean force)}: a non-force
 * drain is skipped while {@code nowNanos - lastNonForceDrainNanos <
 * minInterval} (interval = cached flush-frequency nanos, default 10s); a
 * completed non-force drain records the timestamp; {@code force == true}
 * bypasses unconditionally.
 *
 * <p>NMS-light (TempDir + bootstrap). Each test uses a fresh unique folder
 * (separate coordinator) for isolation; the static BY_FOLDER registry is
 * shared, so assertions are per-coordinator deltas.
 *
 * <p>RECONCILE WITH A-I1 (gate not yet in this worktree at time of writing):
 * this class calls two assumed test hooks following the existing
 * {@code linear$...ForTests} convention (same package, so package-private
 * statics are visible, as with {@code linear$setFlushFrequencyForTests}).
 * Exact assumed signatures:
 * <ul>
 *   <li>{@code LinearFlushCoordinator.linear$resetDrainGateForTests()} —
 *       clears the global last-non-force-drain timestamp. REQUIRED for
 *       isolation: the timestamp is global and other test classes call
 *       {@code flushAllDirty(false)} in the same JVM, which would otherwise
 *       suppress our drains nondeterministically.</li>
 *   <li>{@code LinearFlushCoordinator.linear$lastNonForceDrainNanosForTests()}
 *       — returns the global last-non-force-drain timestamp nanos
 *       ({@code 0} = never). Load-bearing discriminator in
 *       {@link #secondDrainWithinWindowDrainsNothing}: counters alone cannot
 *       tell window-gate suppression apart from the age gate holding a young
 *       file, so the test asserts the suppressed pass records no new
 *       timestamp.</li>
 * </ul>
 * If A-I1 named these differently, rename the call sites (only this file).
 */
public class LinearDrainGateTest {

    /** Age margin matching LinearAgeBasedFlushTest (1s frequency + 1200ms sleep). */
    private static final long AGING_SLEEP_MILLIS = 1200L;

    @TempDir
    private Path tempDir;

    @BeforeAll
    static void bootstrapNms() {
        SharedConstants.tryDetectVersion();
        Bootstrap.bootStrap();
    }

    @AfterEach
    void clearOverrides() {
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(null);
        LinearFlushCoordinator.linear$setFlushThreadsForTests(null);
        LinearFlushCoordinator.linear$resetFlushPoolForTests();
        LinearFlushCoordinator.linear$resetDrainGateForTests();
    }

    private static void writeChunk(Path file, int level, int x, int z) throws Exception {
        Files.createDirectories(file.getParent());
        try (LinearRegionFile region = new LinearRegionFile(file, level)) {
            byte[] payload = new byte[64];
            for (int i = 0; i < payload.length; i++) {
                payload[i] = (byte) (x + z + i);
            }
            region.write(new ChunkPos(x, z), ByteBuffer.wrap(payload));
            region.flush();
        }
    }

    private static void markDirtyThroughReopen(LinearFlushCoordinator coordinator, Path file, int level)
            throws Exception {
        try (LinearRegionFile reopen = new LinearRegionFile(file, level)) {
            coordinator.markDirty(reopen);
        }
    }

    @Test
    public void secondDrainWithinWindowDrainsNothing() throws Exception {
        // NOTE on frequency: the task text says 10s, but a young file under a
        // 10s frequency never drains on the FIRST pass either (age gate holds
        // it, so no gate timestamp is recorded and the window never starts).
        // 1s + aging sleep preserves the test's intent — the first non-force
        // drain genuinely completes and arms the window — at ~1.2s runtime
        // instead of a 10s sleep.
        Path dir = this.tempDir.resolve("gate-window");
        Path file = dir.resolve("r.0.0.linear");
        writeChunk(file, 9, 0, 0);
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(1L);
        LinearFlushCoordinator.linear$resetDrainGateForTests();

        markDirtyThroughReopen(coordinator, file, 9);
        Thread.sleep(AGING_SLEEP_MILLIS); // age past the 1s frequency
        LinearFlushCoordinator.flushAllDirty(false);
        long flushedAfterFirst = coordinator.snapshot().filesFlushed();
        assertTrue(flushedAfterFirst >= 1L, "first non-force drain completes and flushes");
        long gateTimestamp = LinearFlushCoordinator.linear$lastNonForceDrainNanosForTests();
        assertTrue(gateTimestamp > 0L, "completed non-force drain records the gate timestamp");

        // Re-dirty immediately (young file) and drain again at once: the
        // window gate must suppress the pass even though the folder is dirty.
        markDirtyThroughReopen(coordinator, file, 9);
        assertEquals(1, coordinator.dirtyCount(), "re-dirtied file tracked");
        LinearFlushCoordinator.flushAllDirty(false);
        assertEquals(flushedAfterFirst, coordinator.snapshot().filesFlushed(),
            "second drain within the window flushes nothing additional");
        assertEquals(1, coordinator.dirtyCount(), "suppressed file stays tracked");
        assertEquals(gateTimestamp, LinearFlushCoordinator.linear$lastNonForceDrainNanosForTests(),
            "suppressed pass records no new gate timestamp");
    }

    @Test
    public void drainAfterWindowLapsesDrains() throws Exception {
        Path dir = this.tempDir.resolve("gate-lapse");
        Path file = dir.resolve("r.1.1.linear");
        writeChunk(file, 9, 33, 33);
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(1L);
        LinearFlushCoordinator.linear$resetDrainGateForTests();

        markDirtyThroughReopen(coordinator, file, 9);
        Thread.sleep(AGING_SLEEP_MILLIS);
        LinearFlushCoordinator.flushAllDirty(false);
        long flushedAfterFirst = coordinator.snapshot().filesFlushed();
        assertTrue(flushedAfterFirst >= 1L, "first drain flushes and arms the window");

        // Re-dirty, then let BOTH the file age and the window lapse (no marks
        // during the sleep, so the opportunistic markDirty driver cannot fire).
        markDirtyThroughReopen(coordinator, file, 9);
        assertEquals(1, coordinator.dirtyCount(), "re-dirtied file tracked");
        Thread.sleep(AGING_SLEEP_MILLIS);
        LinearFlushCoordinator.flushAllDirty(false);
        assertTrue(coordinator.snapshot().filesFlushed() > flushedAfterFirst,
            "drain past the window lapses the gate and flushes");
        assertEquals(0, coordinator.dirtyCount(), "lapsed-window drain clears tracking");
        assertTrue(Files.size(file) > 40L, "flushed file materialised");
    }

    @Test
    public void forcedDrainBypassesGate() throws Exception {
        Path dir = this.tempDir.resolve("gate-force");
        Path file = dir.resolve("r.2.2.linear");
        writeChunk(file, 9, 65, 65);
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(1L);
        LinearFlushCoordinator.linear$resetDrainGateForTests();

        // Arm a FRESH window timestamp with a genuinely completed non-force drain.
        markDirtyThroughReopen(coordinator, file, 9);
        Thread.sleep(AGING_SLEEP_MILLIS);
        LinearFlushCoordinator.flushAllDirty(false);
        long flushedAfterFirst = coordinator.snapshot().filesFlushed();
        assertTrue(flushedAfterFirst >= 1L, "arming drain completes");

        // Widen the window to 3600s so "within window" holds under either
        // interval-reading implementation (fresh read or captured at drain),
        // then dirty a young file the age gate would also hold: only force
        // may drain it.
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(3600L);
        markDirtyThroughReopen(coordinator, file, 9);
        assertEquals(1, coordinator.dirtyCount(), "young file tracked under both gates");
        LinearFlushCoordinator.flushAllDirty(true);
        assertTrue(coordinator.snapshot().filesFlushed() > flushedAfterFirst,
            "forced drain bypasses the window gate");
        assertEquals(0, coordinator.dirtyCount(), "forced drain clears tracking");
        assertTrue(Files.size(file) > 40L, "forced file materialised");
    }
}
