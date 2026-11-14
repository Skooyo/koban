package io.github.skooyo.koban

/**
 * One lock for the 0.1.1 data import. The app engine and the capture engine both can start it.
 * One owner holds the gate. Other owners wait in arrival order.
 */
object ImportGate {
    private val lock = Any()
    private var holder: Any? = null
    private val waiting = ArrayDeque<Pair<Any, () -> Unit>>()

    /** Calls [onGranted] at once when the gate is free. Else it calls it after the earlier owners release. */
    fun acquire(owner: Any, onGranted: () -> Unit) {
        val grantNow = synchronized(lock) {
            if (holder == null) {
                holder = owner
                true
            } else {
                waiting.addLast(owner to onGranted)
                false
            }
        }
        if (grantNow) onGranted()
    }

    /** Frees the gate when [owner] holds it. The next waiting owner gets it. */
    fun release(owner: Any) {
        val next = synchronized(lock) {
            if (holder !== owner) return
            holder = null
            waiting.removeFirstOrNull()?.also { holder = it.first }
        }
        next?.second?.invoke()
    }

    /** Drops the waits of [owner]. Frees the gate when [owner] holds it. Call it when the engine detaches. */
    fun forget(owner: Any) {
        synchronized(lock) { waiting.removeAll { it.first === owner } }
        release(owner)
    }
}
