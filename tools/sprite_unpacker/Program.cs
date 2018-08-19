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
            foreach(var arg in args)
            {
                Unpacker.Unpack(arg);
            }
        }
    }
}
