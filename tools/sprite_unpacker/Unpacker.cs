using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace sprite_unpacker
{
    public class Unpacker
    {
        static string DumpDirectoryPath = (Directory.GetCurrentDirectory() + "/Dump_" + DateTime.UtcNow.Millisecond);

        const string FramesKey = "FRAMES";
        const string FrameSizeKey = "SPRITE_SIZE";
        
        class Row
        {
            public string Name;
            public int xPos;
            public int yPos;
            public int paletteIndex = -1;

            public static Row Parse(string line)
            {
                if (string.IsNullOrWhiteSpace(line) || line.Contains("#") || line.Contains(",") == false)
                    return null;

                var cells = line.Replace(" ", "").Split(',');

                var row = new Row();
                row.Name = cells[0];
                row.xPos = int.Parse(cells[1]);
                row.yPos = int.Parse(cells[2]);
                if(cells.Length > 3)
                    row.paletteIndex = int.Parse(cells[3]);

                return row;
            }
        }

        public static void Unpack(string imagePath, string csvPath, int spriteWidth)
        {
            if (Directory.Exists(DumpDirectoryPath) == false)
                Directory.CreateDirectory(DumpDirectoryPath);

            imagePath = Path.GetFullPath(imagePath);
            var img = new Bitmap(imagePath);
            var csv = File.ReadAllLines(csvPath);

            var rows = csv.Select(Row.Parse).Where(r => r != null).ToList();
            var palettes = GetPalettes(img, rows, spriteWidth);

            UnpackSprites(img, rows, spriteWidth, palettes);

            System.Diagnostics.Process.Start(DumpDirectoryPath);
        }

        static void UnpackSprites(Bitmap imgSrc, List<Row> rows, int spriteWidth, Dictionary<int, Color[]> palettes)
        {
            foreach (var row in rows)
            {
                var palette = row.paletteIndex >= 0 ? palettes[row.paletteIndex] : null;
                var outImage = new Bitmap(spriteWidth, spriteWidth);
                for (int x = 0; x < spriteWidth; x++)
                {
                    for (int y = 0; y < spriteWidth; y++)
                    {
                        var inPixel = imgSrc.GetPixel((row.xPos * spriteWidth) + x, (row.yPos * spriteWidth) + y);

                        if(palette != null && palette.Contains(inPixel) == false)
                        {
                            throw new Exception(row.Name + " color " + inPixel + " not in palette " + row.paletteIndex);
                        }

                        outImage.SetPixel(x, y, inPixel);
                    }
                }
                var outPath = DumpDirectoryPath + "/" + row.Name + ".png";
                //outImage.Save(outPath, ImageFormat.Png);

                var bigVersion = new Bitmap(spriteWidth * 8, spriteWidth * 8);
                using (var graphics = Graphics.FromImage(bigVersion))
                {
                    graphics.CompositingMode = CompositingMode.SourceCopy;
                    graphics.CompositingQuality = CompositingQuality.Default;
                    graphics.InterpolationMode = InterpolationMode.NearestNeighbor;
                    graphics.SmoothingMode = SmoothingMode.None;
                    graphics.PixelOffsetMode = PixelOffsetMode.None;

                    graphics.DrawImage(outImage, new Rectangle(0, 0, bigVersion.Width, bigVersion.Height));
                }
                bigVersion.Save(outPath, ImageFormat.Png);
            }
        }

        static Dictionary<int, Color[]> GetPalettes(Bitmap imgSrc, List<Row> rows, int spriteWidth)
        {
            var palettes = new Dictionary<int, Color[]>();
            var palettesRow = rows.First(r => r.Name == "palettes");

            for (int paletteIndex = 0; paletteIndex < 16; paletteIndex++)
            {
                var palette = new Color[4];
                for (int x = 0; x < palette.Length; x++)
                {
                    palette[x] = imgSrc.GetPixel((palettesRow.xPos * spriteWidth) + x, (palettesRow.yPos * spriteWidth) + paletteIndex);
                }
                palettes.Add(paletteIndex, palette);
            }

            return palettes;
        }
    }
}
