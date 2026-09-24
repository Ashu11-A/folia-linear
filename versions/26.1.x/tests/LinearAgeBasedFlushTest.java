package net.linear;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.ByteBuffer;
import java.nio.file.Path;
import java.util.List;

import net.minecraft.SharedConstants;
import net.minecraft.server.Bootstrap;
import net.minecraft.world.level.ChunkPos;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Minecraft-0017 (Loop 3, agent 25): age-based flush + first-dirty ordering.
 *
 * <p>NMS-light (TempDir + bootstrap): verifies flush-frequency gates
 * flushDirty (young files skip, old/forced flush), repeat marks do NOT
 * reorder (first-dirty wins), and the DELIBERATE victim change
 * (longest-unflushed, not least-recently-written).
 */
public class LinearAgeBasedFlushTest {

    private static final int COMPRESSION = 3;

    @TempDir
    private Path tempDir;

    @BeforeAll
    static void bootstrapNms() {
        SharedConstants.tryDetectVersion();
        Bootstrap.bootStrap();
    }

    @AfterEach
    void resetCoordinator() {
        LinearFlushCoordinator.linear$resetFlushPoolForTests();
    }

    private static byte[] pattern(int length, int seed) {
        byte[] out = new byte[length];
        for (int i = 0; i < length; i++) {
            out[i] = (byte) ((seed * 31 + i * 17) & 0xFF);
        }
        return out;
    }

    @Test
    public void youngFilesSkipOldFilesFlush() throws Exception {
        Path dir = this.tempDir.resolve("agegate");
        dir.toFile().mkdirs();
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        // Frequency 10s (default-like): immediate flushDirty must skip young.
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(10L);

        LinearRegionFile a = new LinearRegionFile(dir.resolve("r.0.0.linear"), COMPRESSION);
        try {
            a.write(new ChunkPos(0, 0), ByteBuffer.wrap(pattern(64, 1)));
            coordinator.markDirty(a);
            coordinator.flushDirty();
            assertEquals(0L, coordinator.snapshot().filesFlushed(),
                "young file (age ~0 < 10s) must skip");
            assertEquals(1, coordinator.dirtyCount(), "young file stays tracked");

            // Force immediate: same file now flushes.
            LinearFlushCoordinator.linear$setFlushFrequencyForTests(0L);
            coordinator.flushDirty();
            assertEquals(1L, coordinator.snapshot().filesFlushed(),
                "frequency 0 must drain");
            assertEquals(0, coordinator.dirtyCount(), "drained");
        } finally {
            try { a.close(); } catch (Exception ignored) {}
        }
    }

    @Test
    public void repeatMarkDoesNotReorder() throws Exception {
        Path dir = this.tempDir.resolve("firstdirty");
        dir.toFile().mkdirs();
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(10L);

        LinearRegionFile a = new LinearRegionFile(dir.resolve("r.0.0.linear"), COMPRESSION);
        LinearRegionFile b = new LinearRegionFile(dir.resolve("r.1.0.linear"), COMPRESSION);
        try {
            a.write(new ChunkPos(0, 0), ByteBuffer.wrap(pattern(32, 1)));
            coordinator.markDirty(a);
            b.write(new ChunkPos(32, 0), ByteBuffer.wrap(pattern(32, 2)));
            coordinator.markDirty(b);
            // Repeat mark on A must NOT move it to tail (first-dirty wins).
            a.write(new ChunkPos(1, 0), ByteBuffer.wrap(pattern(32, 3)));
            coordinator.markDirty(a);

            List<AbstractRegionFile> order = coordinator.linear$dirtyOrderForTests();
            assertEquals(2, order.size(), "two tracked");
            assertSame(a, order.get(0), "A stays head (first-dirty, no reorder)");
            assertSame(b, order.get(1), "B stays tail");
        } finally {
            try { a.close(); } catch (Exception ignored) {}
            try { b.close(); } catch (Exception ignored) {}
        }
    }

    @Test
    public void evictForcesYoungFiles() throws Exception {
        Path dir = this.tempDir.resolve("evictforce");
        dir.toFile().mkdirs();
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(3600L);

        LinearRegionFile a = new LinearRegionFile(dir.resolve("r.0.0.linear"), COMPRESSION);
        // Do NOT close a here: evict force-flushes via coordinator, then we
        // verify the file materialised; close after (clean no-op).
        a.write(new ChunkPos(0, 0), ByteBuffer.wrap(pattern(64, 9)));
        coordinator.markDirty(a);
        assertEquals(1, coordinator.dirtyCount(), "tracked");

        // Evict forces regardless of age (unload must not lose young writes).
        // Note: evict removes the registry entry; forFolder afterwards is fresh.
        LinearFlushCoordinator.evict(dir);
        assertTrue(dir.resolve("r.0.0.linear").toFile().exists(),
            "evict must materialise young file despite 3600s frequency");
        try { a.close(); } catch (Exception ignored) {}
    }

    @Test
    public void agedHeadAutoFlushesOnLaterMark() throws Exception {
        // rc2 (D2): opportunistic driver. Production frequency >=1: an aged
        // head flushes on a LATER markDirty with no explicit flushDirty.
        // (Folia autosave / plain save-all never reach flushDirty; without
        // this driver an EDIT workload accumulates dirty files that only a
        // manual save-all flush or shutdown would drain.)
        Path dir = this.tempDir.resolve("opportunistic");
        dir.toFile().mkdirs();
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(1L);

        LinearRegionFile a = new LinearRegionFile(dir.resolve("r.0.0.linear"), COMPRESSION);
        LinearRegionFile b = new LinearRegionFile(dir.resolve("r.1.0.linear"), COMPRESSION);
        try {
            a.write(new ChunkPos(0, 0), ByteBuffer.wrap(pattern(64, 1)));
            coordinator.markDirty(a);
            assertEquals(1, coordinator.dirtyCount(), "A tracked");

            Thread.sleep(1200L); // age A past the 1s frequency
            b.write(new ChunkPos(32, 0), ByteBuffer.wrap(pattern(64, 2)));
            coordinator.markDirty(b); // must auto-flush aged A, keep young B
            assertEquals(1, coordinator.dirtyCount(), "aged A auto-flushed, young B stays");
            assertEquals(1L, coordinator.snapshot().filesFlushed(), "one age-eligible flush");
            assertTrue(coordinator.snapshot().millisSinceLastFlush() >= 0L,
                "flush timestamp advances on auto-flush");
            assertTrue(dir.resolve("r.0.0.linear").toFile().exists(),
                "auto-flushed file materialised");
        } finally {
            try { a.close(); } catch (Exception ignored) {}
            try { b.close(); } catch (Exception ignored) {}
        }
    }

    @Test
    public void youngFilesNeverAutoFlush() throws Exception {
        // rc2 (D2): young files stay tracked across repeat marks (no
        // premature drain, no reorder); production frequency, all young.
        Path dir = this.tempDir.resolve("opportunistic-young");
        dir.toFile().mkdirs();
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(3600L);

        LinearRegionFile a = new LinearRegionFile(dir.resolve("r.0.0.linear"), COMPRESSION);
        LinearRegionFile b = new LinearRegionFile(dir.resolve("r.1.0.linear"), COMPRESSION);
        try {
            a.write(new ChunkPos(0, 0), ByteBuffer.wrap(pattern(32, 1)));
            coordinator.markDirty(a);
            b.write(new ChunkPos(32, 0), ByteBuffer.wrap(pattern(32, 2)));
            coordinator.markDirty(b);
            a.write(new ChunkPos(1, 0), ByteBuffer.wrap(pattern(32, 3)));
            coordinator.markDirty(a);
            assertEquals(2, coordinator.dirtyCount(), "young files stay tracked");
            assertEquals(0L, coordinator.snapshot().filesFlushed(), "no premature flush");
            List<AbstractRegionFile> order = coordinator.linear$dirtyOrderForTests();
            assertSame(a, order.get(0), "first-dirty order kept under driver");
        } finally {
            try { a.close(); } catch (Exception ignored) {}
            try { b.close(); } catch (Exception ignored) {}
        }
    }
}
