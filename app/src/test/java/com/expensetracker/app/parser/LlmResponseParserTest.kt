package com.expensetracker.app.parser

import com.expensetracker.app.data.ParseConfidence
import com.expensetracker.app.data.TransactionType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

class LlmResponseParserTest {

    @Test
    fun parseModelContent_withdrawWithMerchant() {
        val content = """
            {
              "isTransaction": true,
              "amount": 14.23,
              "currency": "MYR",
              "merchant": "Starbucks",
              "transactionType": "WITHDRAW",
              "confidence": "HIGH"
            }
        """.trimIndent()

        val result = LlmResponseParser.parseModelContent(content)
        assertTrue(result is LlmParseResult.Success)
        val expense = (result as LlmParseResult.Success).expense
        assertEquals(BigDecimal("14.23"), expense.amount)
        assertEquals("MYR", expense.currency)
        assertEquals("Starbucks", expense.merchant)
        assertEquals(TransactionType.WITHDRAW, expense.transactionType)
        assertEquals(ParseConfidence.HIGH, expense.confidence)
    }

    @Test
    fun parseModelContent_receiveType() {
        val content = """
            {"isTransaction":true,"amount":100,"currency":"RM","merchant":"Ali","transactionType":"RECEIVE","confidence":"MEDIUM"}
        """.trimIndent()

        val result = LlmResponseParser.parseModelContent(content)
        val expense = (result as LlmParseResult.Success).expense
        assertEquals(BigDecimal("100.00"), expense.amount)
        assertEquals("MYR", expense.currency)
        assertEquals(TransactionType.RECEIVE, expense.transactionType)
        assertEquals(ParseConfidence.MEDIUM, expense.confidence)
    }

    @Test
    fun parseModelContent_notTransaction_returnsNotTransaction() {
        val content = """
            {
              "isTransaction": false,
              "reason": "promotional offer",
              "amount": null,
              "merchant": null,
              "transactionType": null,
              "confidence": null
            }
        """.trimIndent()

        val result = LlmResponseParser.parseModelContent(content)
        assertTrue(result is LlmParseResult.NotTransaction)
        assertEquals("promotional offer", (result as LlmParseResult.NotTransaction).reason)
    }

    @Test
    fun parseModelContent_promoWithRmAmount_stillRejected() {
        val content = """
            {
              "isTransaction": false,
              "reason": "marketing cashback tease",
              "amount": 10.0,
              "currency": "MYR",
              "merchant": null,
              "transactionType": null,
              "confidence": null
            }
        """.trimIndent()

        val result = LlmResponseParser.parseModelContent(content)
        assertEquals(
            LlmParseResult.NotTransaction("marketing cashback tease"),
            result
        )
    }

    @Test
    fun parseModelContent_legacyIsPaymentNotificationFalse_stillRejected() {
        val content = """{"isPaymentNotification":false,"reason":"OTP"}"""
        val result = LlmResponseParser.parseModelContent(content)
        assertEquals(LlmParseResult.NotTransaction("OTP"), result)
    }

    @Test
    fun parseModelContent_skipFlag_returnsNotTransaction() {
        val content = """{"skip":true}"""
        assertEquals(LlmParseResult.NotTransaction("skipped"), LlmResponseParser.parseModelContent(content))
    }

    @Test
    fun parseModelContent_markdownFencedJson_stillParses() {
        val content = """
            ```json
            {"isTransaction":true,"amount":25.5,"currency":"MYR","merchant":"ABC Mart","transactionType":"WITHDRAW","confidence":"HIGH"}
            ```
        """.trimIndent()

        val result = LlmResponseParser.parseModelContent(content)
        val expense = (result as LlmParseResult.Success).expense
        assertEquals(BigDecimal("25.50"), expense.amount)
        assertEquals("ABC Mart", expense.merchant)
    }

    @Test
    fun parseModelContent_invalidJson_returnsFailed() {
        assertEquals(LlmParseResult.Failed, LlmResponseParser.parseModelContent("not json"))
    }

    @Test
    fun parseModelContent_nullMerchant_becomesNull() {
        val content = """
            {"isTransaction":true,"amount":10,"currency":"MYR","merchant":null,"transactionType":"WITHDRAW","confidence":"LOW"}
        """.trimIndent()

        val expense = (LlmResponseParser.parseModelContent(content) as LlmParseResult.Success).expense
        assertNull(expense.merchant)
        assertEquals(ParseConfidence.LOW, expense.confidence)
    }

    @Test
    fun parseModelContent_isTransactionTrueButMissingAmount_returnsFailed() {
        val content = """{"isTransaction":true,"amount":null,"merchant":"X","transactionType":"WITHDRAW"}"""
        assertEquals(LlmParseResult.Failed, LlmResponseParser.parseModelContent(content))
    }

    @Test
    fun parseChatCompletionsBody_extractsMessageContent() {
        val body = """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\"isTransaction\":true,\"amount\":8.50,\"currency\":\"MYR\",\"merchant\":\"TnG Merchant\",\"transactionType\":\"WITHDRAW\",\"confidence\":\"HIGH\"}"
                  }
                }
              ]
            }
        """.trimIndent()

        val result = LlmResponseParser.parseChatCompletionsBody(body)
        val expense = (result as LlmParseResult.Success).expense
        assertEquals(BigDecimal("8.50"), expense.amount)
        assertEquals("TnG Merchant", expense.merchant)
    }

    @Test
    fun parseChatCompletionsBody_notTransaction_propagates() {
        val body = """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\"isTransaction\":false,\"reason\":\"balance update only\"}"
                  }
                }
              ]
            }
        """.trimIndent()

        assertEquals(
            LlmParseResult.NotTransaction("balance update only"),
            LlmResponseParser.parseChatCompletionsBody(body)
        )
    }

    @Test
    fun parseChatCompletionsBody_emptyChoices_returnsFailed() {
        assertEquals(
            LlmParseResult.Failed,
            LlmResponseParser.parseChatCompletionsBody("""{"choices":[]}""")
        )
    }

    @Test
    fun parseGenerateContentBody_extractsCandidateText() {
        val body = """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      {
                        "text": "{\"isTransaction\":true,\"amount\":12.5,\"currency\":\"MYR\",\"merchant\":\"KK - SUPER MART - UMN\",\"transactionType\":\"WITHDRAW\",\"confidence\":\"HIGH\"}"
                      }
                    ]
                  }
                }
              ]
            }
        """.trimIndent()

        val expense = (LlmResponseParser.parseGenerateContentBody(body) as LlmParseResult.Success).expense
        assertEquals(BigDecimal("12.50"), expense.amount)
        assertEquals("KK - SUPER MART - UMN", expense.merchant)
    }

    @Test
    fun parseGenerateContentBody_emptyCandidates_returnsFailed() {
        assertEquals(
            LlmParseResult.Failed,
            LlmResponseParser.parseGenerateContentBody("""{"candidates":[]}""")
        )
    }
}
