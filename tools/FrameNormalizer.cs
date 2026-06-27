using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class FrameNormalizer
{
    public static int[] GetBoundingBox(Bitmap bmp)
    {
        int w = bmp.Width, h = bmp.Height;
        var rect = new Rectangle(0, 0, w, h);
        var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = data.Stride;
        byte[] pixels = new byte[Math.Abs(stride) * h];
        Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);
        bmp.UnlockBits(data);

        int minX = w, maxX = -1, minY = h, maxY = -1;
        for (int y = 0; y < h; y++)
        {
            int rowOff = y * stride;
            for (int x = 0; x < w; x++)
            {
                if (pixels[rowOff + x * 4 + 3] > 10)
                {
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }
        }
        if (maxX == -1) return null;
        return new int[] { minX, maxX, minY, maxY };
    }

    public static Bitmap ResizeImage(Bitmap src, double scale)
    {
        int newW = (int)Math.Round(src.Width * scale);
        int newH = (int)Math.Round(src.Height * scale);
        var dest = new Bitmap(newW, newH, PixelFormat.Format32bppArgb);
        dest.SetResolution(96, 96);
        using (var g = Graphics.FromImage(dest))
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.CompositingMode = CompositingMode.SourceCopy;
            g.DrawImage(src, 0, 0, newW, newH);
        }
        return dest;
    }

    public static void NormalizeFrame(string inputPath, string outputPath,
        double scale, bool isAir, int airOffset, int canvasW, int canvasH, int baselineY)
    {
        using (var src = new Bitmap(inputPath))
        {
            Bitmap work = (scale != 1.0) ? ResizeImage(src, scale) : src;

            int[] bbox = GetBoundingBox(work);
            if (bbox == null)
            {
                using (var canvas = new Bitmap(canvasW, canvasH, PixelFormat.Format32bppArgb))
                {
                    canvas.SetResolution(96, 96);
                    canvas.Save(outputPath, ImageFormat.Png);
                }
                if (work != src) work.Dispose();
                return;
            }

            int bboxW = bbox[1] - bbox[0] + 1;
            int bboxCenterX = bbox[0] + bboxW / 2;
            int footY = bbox[3];

            int offsetX = canvasW / 2 - bboxCenterX;
            int offsetY;

            if (isAir)
            {
                offsetY = -airOffset;
            }
            else
            {
                offsetY = baselineY - footY;
            }

            using (var canvas = new Bitmap(canvasW, canvasH, PixelFormat.Format32bppArgb))
            {
                canvas.SetResolution(96, 96);
                using (var g = Graphics.FromImage(canvas))
                {
                    g.CompositingMode = CompositingMode.SourceOver;
                    g.DrawImage(work, offsetX, offsetY, work.Width, work.Height);
                }
                canvas.Save(outputPath, ImageFormat.Png);
            }

            if (work != src) work.Dispose();
        }
    }

    public static int GetFootY(string inputPath, double scale)
    {
        using (var src = new Bitmap(inputPath))
        {
            Bitmap work = (scale != 1.0) ? ResizeImage(src, scale) : src;
            int[] bbox = GetBoundingBox(work);
            int result = (bbox != null) ? bbox[3] : -1;
            if (work != src) work.Dispose();
            return result;
        }
    }
}
