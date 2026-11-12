package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.SettingsRepository
import com.expensetracker.app.groups.GroupDetail
import com.expensetracker.app.groups.GroupRepository
import com.expensetracker.app.groups.GroupsState
import com.expensetracker.app.groups.Period
import com.expensetracker.app.groups.SupabaseException
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/** The Groups tab and one group's screen. [groupId] is set only on the group screen. */
@HiltViewModel
class GroupsViewModel @Inject constructor(
    private val repo: GroupRepository,
    private val settings: SettingsRepository,
    savedState: SavedStateHandle
) : ViewModel() {
    private val groupId: String? = savedState["groupId"]

    val state: StateFlow<GroupsState> = repo.state

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _period = MutableStateFlow(Period.MONTH)
    val period: StateFlow<Period> = _period.asStateFlow()

    private val _detail = MutableStateFlow<GroupDetail?>(null)
    val detail: StateFlow<GroupDetail?> = _detail.asStateFlow()

    /** False after a load that found the group gone (left, removed or deleted). */
    private val _groupExists = MutableStateFlow(true)
    val groupExists: StateFlow<Boolean> = _groupExists.asStateFlow()

    init { refresh() }

    fun refresh() = run(silent = true) {
        syncTotals()
        refresh()
        null
    }

    fun setPeriod(p: Period) {
        _period.value = p
        reload()
    }

    /**
     * Runs one group action. [onOk] runs when it worked; an error goes to [message].
     * Every action ends with a fresh read of the open group.
     */
    fun run(silent: Boolean = false, onOk: () -> Unit = {}, block: suspend GroupRepository.() -> String?) {
        viewModelScope.launch {
            if (!silent) _busy.value = true
            val error = repo.block()
            reloadNow()
            _busy.value = false
            if (error == null) onOk() else _message.value = error
        }
    }

    fun setOnline(on: Boolean) = viewModelScope.launch { settings.setOnlineFeatures(on) }

    fun messageShown() { _message.value = null }

    private fun reload() = viewModelScope.launch { reloadNow() }

    private suspend fun reloadNow() {
        val id = groupId ?: return
        if (repo.state.value.userId != null && repo.state.value.groups.none { it.id == id }) {
            _groupExists.value = false
            return
        }
        try {
            // ponytail: RM only until the Rp account ships on main; then pass the Settings active account.
            _detail.value = repo.loadGroup(id, _period.value, "MYR")
        } catch (e: SupabaseException) {
            _message.value = if (e.code == 0) "Could not reach Koban's server. Check the internet connection." else "Could not load the group. Try again."
        }
    }
}
