using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;

namespace GeneralLibrary
{
    class TestSocket
    {
        public static void Run()
        {
            // Sensitive
            Socket socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);

            // TcpClient and UdpClient simply abstract the details of creating a Socket
            TcpClient client = new TcpClient("example.com", 80); // Sensitive
            UdpClient listener = new UdpClient(80); // Sensitive
        }
    }
}
