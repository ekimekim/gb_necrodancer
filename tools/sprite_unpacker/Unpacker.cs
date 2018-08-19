using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace sprite_unpacker
{
    public class Unpacker
    {
        const string FramesKey = "FRAMES";
        const string FrameSizeKey = "SPRITE_SIZE";

        public static void Unpack(string imagePath)
        {
            imagePath = Path.GetFullPath(imagePath);
            var img = new Bitmap(imagePath);
            var csv = File.ReadAllLines(imagePath.Replace(".png", ".unpack.csv"));

            int frames;
            Point frameSize;
            GetData(csv, out frames, out frameSize);

            var directory = Path.GetDirectoryName(imagePath);

            UnpackSprites(img, csv, frames, frameSize, directory);

            //Bitmap image, string[] csv

        }

        static void UnpackSprites(Bitmap imgSrc, string[] csv, int frames, Point spriteSize, string directory)
        {
            var bigFrameWidth = imgSrc.Width / frames;


            foreach (var rowRaw in csv)
            {
                if (string.IsNullOrWhiteSpace(rowRaw) || rowRaw.Contains(";") || rowRaw.Contains(FramesKey) || rowRaw.Contains(FrameSizeKey))
                    continue;

                var cells = rowRaw.Replace(" ", "").Split(',');

                var name = cells[0];
                var cellPos = new Point(int.Parse(cells[1]), int.Parse(cells[2]));

                for (int frameIndex = 0; frameIndex < frames; frameIndex++)
                {
                    var outputImg = new Bitmap(spriteSize.X, spriteSize.Y);

                    var colors = new List<Color>();

                    for (int x = 0; x < spriteSize.X; x++)
                    {
                        for (int y = 0; y < spriteSize.Y; y++)
                        {
                            var inX = (frameIndex * bigFrameWidth) + (cellPos.X * spriteSize.X) + x;
                            var inY = (cellPos.Y * spriteSize.Y) + y;

                            var inPixel = imgSrc.GetPixel(inX, inY);
                            outputImg.SetPixel(x, y, inPixel);

                            if(colors.Any(c => c == inPixel) == false)
                            {
                                colors.Add(inPixel);
                            }
                        }
                    }
                    
                    // Sort Colors
                    colors = colors.OrderBy(c => c.A).ThenBy(c => c.R).ThenBy(c => c.G).ThenBy(c => c.B).ToList();

                    if (colors.Count > 4)
                        throw new Exception("Too many colors in " + name);

                    var imagePath = string.Format("{0}/{1}_{2}.png", directory, name, frameIndex);
                    outputImg.Save(imagePath, ImageFormat.Png);

                    var palettePath = string.Format("{0}/{1}_{2}.json", directory, name, frameIndex);
                    WriteImageMeta(palettePath, imagePath, colors);
                }
            }
        }

        static void WriteImageMeta(string palettePath, string imagePath, List<Color> colors)
        {
            var jsonWrite = new StreamWriter(palettePath);

            jsonWrite.WriteLine("{");
            jsonWrite.WriteLine("\t\"image\": " + Path.GetFileName(imagePath) + "\",");
            jsonWrite.WriteLine("\t\"pallette\": [");
            for (int i = 0; i < 4; i++)
            {
                var paletteColor = Color.Black;
                if (colors.Count > i && colors[i].A > 0)
                    paletteColor = colors[i];

                var endChar = (i != 3) ? "," : "";

                var paletteColorLine = string.Format("\t\t[{0}, {1}, {2}]{3}", paletteColor.R, paletteColor.G, paletteColor.B, endChar);

                jsonWrite.WriteLine(paletteColorLine);
            }
            jsonWrite.WriteLine("\t]");
            jsonWrite.WriteLine("}");

            jsonWrite.Close();
        }

        static void GetData(string[] csv, out int frames, out Point size)
        {
            var framesRow = csv.First(l => l.Contains(FramesKey)).Replace(" ", "").Split(',');
            var sizeRow = csv.First(l => l.Contains(FrameSizeKey)).Replace(" ", "").Split(',');

            frames = int.Parse(framesRow[1]);
            size = new Point(int.Parse(sizeRow[1]), int.Parse(sizeRow[2]));
        }
    }
}
