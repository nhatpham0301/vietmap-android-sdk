package com.mapbox.mapboxsdk.module.http

import com.mapbox.mapboxsdk.MapboxInjector
import com.mapbox.mapboxsdk.utils.ConfigUtils
import io.mockk.mockk
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class HttpRequestUtilTest {

    @Test
    fun replaceHttpClient() {
        MapboxInjector.inject(mockk(relaxed = true), "", ConfigUtils.getMockedOptions())

        assertEquals(HttpRequestImpl.DEFAULT_CLIENT, HttpRequestImpl.client)

        val httpMock = mockk<OkHttpClient>()
        HttpRequestUtil.setOkHttpClient(httpMock)
        assertEquals(
            "Http client should have set to the mocked client",
            httpMock,
            HttpRequestImpl.client
        )

        HttpRequestUtil.setOkHttpClient(null)
        assertEquals(
            "Http client should have been reset to the default client",
            HttpRequestImpl.DEFAULT_CLIENT,
            HttpRequestImpl.client
        )

        MapboxInjector.clear()
    }
}
