using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace sprite_unpacker
{
    class Program
    {
        static void Main(string[] args)
        {
            for (int i = 0; i < args.Length; i++)
            {
                if(args[i] == "-sprite8")
                {
                    var imagePath = args[i + 1];
                    var csvPath = args[i + 2];
                    Unpacker.Unpack(imagePath, csvPath, 8);
                }
                if (args[i] == "-sprite16")
                {
                    var imagePath = args[i + 1];
                    var csvPath = args[i + 2];
                    Unpacker.Unpack(imagePath, csvPath, 16);
                }
            }
        }
    }
}
