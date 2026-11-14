package com.expensetracker.app.listener

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class PaymentAppsMirrorTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test fun readIsNullBeforeTheFirstWrite() = assertNull(PaymentAppsMirror.read(context))

    @Test fun writeThenReadGivesTheSameSet() {
        PaymentAppsMirror.write(context, setOf("com.maybank2u.life", "my.com.tngdigital.ewallet"))
        assertEquals(setOf("com.maybank2u.life", "my.com.tngdigital.ewallet"), PaymentAppsMirror.read(context))
    }

    @Test fun anEmptySetIsNotNull() {
        PaymentAppsMirror.write(context, emptySet())
        assertEquals(emptySet<String>(), PaymentAppsMirror.read(context))
    }
}
