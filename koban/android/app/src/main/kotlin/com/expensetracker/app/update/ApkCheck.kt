package com.expensetracker.app.update

object ApkCheck {
    /** True only for a Koban APK of the expected version. Null values mean the file is not an APK. */
    fun matches(archivePackage: String?, archiveVersionCode: Long?, expectedPackage: String, expectedVersionCode: Int): Boolean =
        archivePackage == expectedPackage && archiveVersionCode == expectedVersionCode.toLong()
}
