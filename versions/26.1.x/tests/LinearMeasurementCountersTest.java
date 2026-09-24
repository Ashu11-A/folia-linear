package net.linear;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.ByteBuffer;
import java.nio.file.Path;

import net.minecraft.SharedConstants;
import net.minecraft.server.Bootstrap;
import net.minecraft.world.level.ChunkPos;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Minecraft-0015 (Loop 3, agent 23): Loop-4 measurement counters.
 *
 * <p>NMS-light (TempDir + bootstrap): verifies compressed vs raw bytes,
 * flush p50/p99, millis-since-flush, and the S8 blind-spot fix (markDirty +
 * cache hits/misses separate "never invoked" from "empty set"). Lock-free
 * only (LongAdder/LongAccumulator, no synchronized on hot paths -- verified
 * by inspection; this test pins behaviour).
 */
public class LinearMeasurementCountersTest {

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
        // Minecraft-0017: clear age/pool overrides (frequency 0 forced below).
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
    public void emptySnapshotHasSentinels() {
        Path dir = this.tempDir.resolve("emptymeas");
        dir.toFile().mkdirs();
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        LinearRegionTimings.LinearFolderSnapshot snap = coordinator.snapshot();
        assertEquals(0L, snap.rawBytes(), "rawBytes starts 0");
        assertEquals(0L, snap.compressedBytes(), "compressedBytes starts 0");
        assertEquals(0L, snap.flushP50Micros(), "p50 starts 0");
        assertEquals(0L, snap.flushP99Micros(), "p99 starts 0");
        assertEquals(-1L, snap.millisSinceLastFlush(), "never-flushed sentinel -1");
        assertEquals(0L, snap.markDirty(), "markDirty starts 0 (never invoked)");
        assertEquals(0L, snap.cacheHits(), "cacheHits starts 0");
        assertEquals(0L, snap.cacheMisses(), "cacheMisses starts 0");
    }

    @Test
    public void flushRecordsBytesAndLatency() throws Exception {
        Path dir = this.tempDir.resolve("byteslat");
        dir.toFile().mkdirs();
        Path file = dir.resolve("r.0.0.linear");
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();
        // Minecraft-0017: force immediate so coordinator.flushDirty drains.
        LinearFlushCoordinator.linear$setFlushFrequencyForTests(0L);

        LinearRegionFile region = new LinearRegionFile(file, COMPRESSION);
        try {
            region.write(new ChunkPos(0, 0), ByteBuffer.wrap(pattern(512, 5)));
            // Mark-dirty via coordinator so markDirty count is exercised too.
            coordinator.markDirty(region);
            region.flush();
            // Ensure folder success timestamp via coordinator path as well.
            coordinator.flushDirty();
        } finally {
            region.close();
        }

        LinearRegionTimings.LinearFolderSnapshot snap = coordinator.snapshot();
        assertTrue(snap.rawBytes() > 0L, "rawBytes>0 after flush, was " + snap.rawBytes());
        assertTrue(snap.compressedBytes() > 0L, "compressedBytes>0 after flush");
        assertTrue(snap.compressedBytes() <= snap.rawBytes() + 8192L,
            "compressed should be near raw for small region (raw=" + snap.rawBytes()
            + " compressed=" + snap.compressedBytes() + ")");
        assertTrue(snap.flush().count() >= 1L, "flush count>=1");
        assertTrue(snap.flushP50Micros() >= 0L, "p50>=0");
        assertTrue(snap.flushP99Micros() >= snap.flushP50Micros(),
            "p99>=p50 (p50=" + snap.flushP50Micros() + " p99=" + snap.flushP99Micros() + ")");
        assertTrue(snap.millisSinceLastFlush() >= 0L,
            "millisSince>=0 after success, was " + snap.millisSinceLastFlush());
        assertTrue(snap.millisSinceLastFlush() < 60_000L, "millisSince recent (<60s)");
        assertTrue(snap.markDirty() >= 1L, "markDirty>=1 after markDirty()");
        assertTrue(snap.filesFlushed() >= 1L, "filesFlushed>=1");
    }

    @Test
    public void markDirtyAndCacheCountsSeparateNeverFromEmpty() throws Exception {
        Path dir = this.tempDir.resolve("blindspot");
        dir.toFile().mkdirs();
        LinearFlushCoordinator coordinator = LinearFlushCoordinator.forFolder(dir);
        coordinator.resetForTests();

        // Empty set: snapshot entry exists (via forFolder) but counts zero.
        LinearRegionTimings.LinearFolderSnapshot empty = coordinator.snapshot();
        assertEquals(0L, empty.markDirty(), "empty set markDirty 0");
        assertEquals(0L, empty.cacheHits() + empty.cacheMisses(), "empty set cache 0");

        // Invoke markDirty + cache hit/miss bridges, then verify separation.
        Path file = dir.resolve("r.5.5.linear");
        LinearRegionFile region = new LinearRegionFile(file, COMPRESSION);
        try {
            region.write(new ChunkPos(5 * 32, 5 * 32), ByteBuffer.wrap(pattern(64, 9)));
            coordinator.markDirty(region);
            coordinator.reportCacheHit();
            coordinator.reportCacheMiss();
            coordinator.reportCacheMiss();
        } finally {
            region.close();
        }
        LinearRegionTimings.LinearFolderSnapshot after = coordinator.snapshot();
        assertTrue(after.markDirty() >= 1L, "never-invoked (0) vs invoked (>=1)");
        assertTrue(after.cacheHits() >= 1L, "cacheHits>=1");
        assertTrue(after.cacheMisses() >= 2L, "cacheMisses>=2");
    }
}
