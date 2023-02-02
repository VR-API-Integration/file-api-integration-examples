using FileAPI.MFT.Utils;
using System.Threading.Tasks;
using Xunit;
using Xunit.Abstractions;

namespace FileAPI.MFT.Streaming.NetCore22.Examples
{
    public class Delete : Startup
    {
        private readonly ITestOutputHelper _output;

        public Delete(ITestOutputHelper output)
        {
            _output = output;
        }

        [Fact]
        public async Task SetSubscriberFileToDeleted()
        {
            // To set a file to 'deleted', you need to provide its file Id.
            // Also, if you have a multitenant-token, the tenantId needs to be provided. 

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.

            #endregion

            _output.WriteTittle("Executing Streaming.SDK example: Set subscriber file to 'deleted'");

            // Configure the file id.
            var fileId = "FileId";

            // Delete the file.
            var deleteResult = await Streaming.DeleteFileAsync(fileId: fileId, tenantId: tenantId);

            Assert.True(deleteResult);

            // Print the result.
            _output.WriteLine($"File could be deleted:{deleteResult}");
        }
    }
}
