package com.example.widget_memories

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.widget.ImageView
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

/**
 * Implementation of App Widget functionality.
 */
class PhotoWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.photo_widget).apply {
                val imageName = widgetData.getString("filename", null)

                val bitmap: Bitmap = when {
                    imageName == null -> createBlackImage()
                    else -> {
                        val imageFile = File(imageName)
                        if (imageFile.exists()) {
                            BitmapFactory.decodeFile(imageFile.absolutePath)
                        } else {
                            createBlackImage()
                        }
                    }
                }

                val aspectRatio = bitmap.width / bitmap.height.toFloat()
                val width = 1000
                val height = Math.round(width / aspectRatio)
                val scaledBitmap = Bitmap.createScaledBitmap(
                    bitmap,
                    width,
                    height,
                    true
                )

                setImageViewBitmap(R.id.widget_image, scaledBitmap)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    fun createBlackImage(id: Int = R.id.widget_image): Bitmap {
        val width = 200
        val height = 200
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.BLACK) // Fill the bitmap with black color
        return bitmap
    }
}

