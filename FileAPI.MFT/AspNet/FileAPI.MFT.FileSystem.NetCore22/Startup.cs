using Ftaas.Sdk.FileSystem;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.IO;
using System.Threading.Tasks;

namespace FileAPI.MFT.FileSystem.NetCore22
{
    public class Startup
    {
        protected IService FileSystem { get; }

        protected IConfigurationRoot Config { get; }

        protected readonly string FilesBaseDirectory = Path.Combine(Environment.CurrentDirectory, "Files");

        public Startup()
        {
            Config = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("config.json")
                .Build();

            // Inject the FileSystem.SDK service.
            var services = new ServiceCollection();
            services.AddFileSystemService(
                options =>
                {
                    // File API endpoint.
                    // -Test: https://api-test.raet.com/mft/v1.0/
                    // -Acceptance: https://api-acc.raet.com/mft/v1.0/
                    // -Production: https://api.raet.com/mft/v1.0/
                    options.MftServiceBaseAddress = Config.GetValue<string>("mtf_service_base_address");

                    // Optional value. Maximum number of bytes that will be uploaded on a call to File API.
                    // The file will be splitted on chunks of this size and uploaded on different calls.
                    // If not set, the default value is the maximum size accepted on File API: 4194304, 4 MB.
                    // The default value is also the recommended one, only to be decreased if you are having connection issues.
                    options.ChunkMaxBytesSize = Config.GetValue<int>("chunk_max_bytes_size");

                    // Optional value. With a higher timeout it is possible to operate larger files without a Timeout exception
                    // This value is valid for all the calls to this service.
                    // If a particular call needs a shorter Timeout, the cancellation token of that particular call can be used
                    options.ClientTimeout = 600;

                    // Optional value. Number of parallel requests to File API.
                    // If not set, the default value is the maximum 6.The minimum is 1.
                    // It's recommended to set this value according to your CPU capabilities.
                    // It's used when uploading a big file (size > ChunkMaxBytesSize) to upload up to ConcurrentConnectionsCount chunks of the file simultaneously
                    // and when performing a multitenant list, retrieving the files for different tenants on parallel.
                    options.ConcurrentConnectionsCount = Config.GetValue<byte>("concurrent_connection_count");
                },
                async (sp) =>
                {
                    // Here comes the logic of retrieving the authentaction token.
                    // This logic is out of the File API scope, but as a guide, you can use something similar
                    // to what is implemented in Examples/RetrieveToken.cs.
                    return await Task.FromResult("MyToken");
                });

            // Get the FileSystem.SDK service.
            var serviceProvider = services.BuildServiceProvider();
            FileSystem = serviceProvider.GetRequiredService<IService>();
        }
    }
}