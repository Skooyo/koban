package com.expensetracker.app.ui.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.expensetracker.app.data.PeopleMath
import com.expensetracker.app.data.PeopleRepository
import com.expensetracker.app.data.PersonSummary
import com.expensetracker.app.data.SplitBillEntity
import com.expensetracker.app.data.SplitRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class PeopleViewModel @Inject constructor(
    private val peopleRepository: PeopleRepository,
    splitRepository: SplitRepository
) : ViewModel() {

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    fun setQuery(value: String) {
        _query.value = value
    }

    /** Non-empty groups in display order, filtered by the search query. */
    val sections: StateFlow<List<Pair<PeopleMath.Group, List<PersonSummary>>>> =
        combine(peopleRepository.observePeople(), _query) { people, q ->
            val key = PeopleMath.normalizedName(q)
            val shown = people.filter { key in PeopleMath.normalizedName(it.person.name) }
            PeopleMath.Group.entries
                .map { group -> group to shown.filter { PeopleMath.group(it.balance) == group } }
                .filter { it.second.isNotEmpty() }
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val bills: StateFlow<List<SplitBillEntity>> = splitRepository.observeBills()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /** Returns the person id. Throws IllegalArgumentException("Enter a name.") for a blank name. */
    suspend fun add(name: String): String = peopleRepository.addPerson(name)
}
