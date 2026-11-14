package io.github.skooyo.koban

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test

class ImportGateTest {
    private val a = Any()
    private val b = Any()
    private val c = Any()
    private val log = mutableListOf<String>()

    @After fun releaseEveryOwner() {
        // Repeat: a release can hand the gate to the next waiting owner.
        repeat(3) { listOf(a, b, c).forEach(ImportGate::forget) }
    }

    @Test fun theFirstOwnerGetsTheGateAtOnce() {
        ImportGate.acquire(a) { log += "a" }
        assertEquals(listOf("a"), log)
    }

    @Test fun theNextOwnerWaitsUntilRelease() {
        ImportGate.acquire(a) { log += "a" }
        ImportGate.acquire(b) { log += "b" }
        assertEquals(listOf("a"), log)
        ImportGate.release(a)
        assertEquals(listOf("a", "b"), log)
    }

    @Test fun aDetachedOwnerFreesTheGateAndDropsItsWait() {
        ImportGate.acquire(a) { log += "a" }
        ImportGate.acquire(b) { log += "b" }
        ImportGate.acquire(c) { log += "c" }
        ImportGate.forget(b)
        ImportGate.forget(a)
        assertEquals(listOf("a", "c"), log)
    }
}
