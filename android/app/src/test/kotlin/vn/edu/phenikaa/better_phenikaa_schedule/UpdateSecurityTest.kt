package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdateSecurityTest {
    @Test fun uidBytesHaveStablePlatformOrder() {
        assertEquals("0080FF10", BoundCardStore.normalize(byteArrayOf(0, -128, -1, 16)))
        assertTrue(BoundCardStore.matches("0080FF10", "0080FF10"))
        assertFalse(BoundCardStore.matches("0080FF10", "1080FF00"))
    }

    @Test fun candidateRequiresExactPackageHigherVersionAndSameSigner() {
        val signer = listOf(byteArrayOf(1, 2, 3))
        CandidateRules.requireValid("vn.edu.phenikaa.better_phenikaa_schedule", 29, 28, 29, signer, signer)
        rejects { CandidateRules.requireValid("other.app", 29, 28, 29, signer, signer) }
        rejects { CandidateRules.requireValid("vn.edu.phenikaa.better_phenikaa_schedule", 29, 28, 28, signer, signer) }
        rejects { CandidateRules.requireValid("vn.edu.phenikaa.better_phenikaa_schedule", 29, 28, 27, signer, signer) }
        rejects { CandidateRules.requireValid("vn.edu.phenikaa.better_phenikaa_schedule", 29, 28, 29, signer, listOf(byteArrayOf(4))) }
        rejects { CandidateRules.requireValid("vn.edu.phenikaa.better_phenikaa_schedule", 29, 28, 29, emptyList(), signer) }
    }

    @Test fun wrongApkHashFails() {
        val good = ByteArray(32) { it.toByte() }
        val hex = good.joinToString("") { "%02x".format(it.toInt() and 0xff) }
        assertTrue(DigestRules.matches(good, hex))
        assertFalse(DigestRules.matches(ByteArray(32), hex))
        assertFalse(DigestRules.matches(good, "not-a-hash"))
    }

    private fun rejects(block: () -> Unit) {
        try { block(); throw AssertionError("Expected rejection") }
        catch (_: IllegalArgumentException) { /* require rejects */ }
    }
}
