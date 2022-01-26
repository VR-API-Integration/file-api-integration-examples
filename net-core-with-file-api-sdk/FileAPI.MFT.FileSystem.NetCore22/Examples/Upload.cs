using FileAPI.MFT.Utils;
using Ftaas.Sdk.Base;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Xunit;
using Xunit.Abstractions;

namespace FileAPI.MFT.FileSystem.NetCore22.Examples
{
    public class Upload : Startup
    {
        private static ITestOutputHelper _output;

        public Upload(ITestOutputHelper output)
        {
            _output = output;
        }

        [Fact]
        public async Task UploadOneFile()
        {
            // To upload a file you need to provide the path of the file and the BusinessType where it's going to be uploaded.
            // Also, if you have a multitenant-token, the tenantId needs to be provided.

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.
            var businessTypeId = 0; // Use the desired businessType.

            #endregion

            _output.WriteTittle("Executing FileSystem.SDK example: Upload one file");

            // Configure the file that is going to be uploaded.
            var fileName = "testFile50kb.txt";
            var filePath = Path.Combine(FilesBaseDirectory, "Data", fileName);

            // Upload the file.
            var uploadResult = await FileSystem.UploadFileAsync(businessTypeId, filePath, tenantId: tenantId);

            Assert.IsType<FileUploadInfo>(uploadResult);
            Assert.Equal(fileName, uploadResult.Name);
            Assert.Equal(51200, uploadResult.Size); // 50 kb

            // Print the result.
            _output.WriteLine("File was uploaded:");
            _output.WriteJson(uploadResult);
        }

        [Fact]
        public async Task UploadTwoFilesInParallel()
        {
            // As the call is asynchronous, it is possible to do several calls in parallel.

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.
            var businessTypeIdBigFile = 0; // Use the desired businessType.
            var businessTypeIdSmallFile = 0; // Use the desired businessType.

            #endregion

            _output.WriteTittle("Executing FileSystem.SDK example: Upload two files in parallel");

            // Configure the files that are going to be uploaded.
            var bigFileName = "testFile10mb.yml";
            var bigFilePath = Path.Combine(FilesBaseDirectory, "Data", bigFileName);

            var smallFileName = "testFile50kb.txt";
            var smallFilePath = Path.Combine(FilesBaseDirectory, "Data", smallFileName);

            // Upload the files.
            var uploadTasks = new List<Task<FileUploadInfo>>
            {
                FileSystem.UploadFileAsync(businessTypeIdBigFile, bigFilePath, tenantId: tenantId),
                FileSystem.UploadFileAsync(businessTypeIdSmallFile, smallFilePath, tenantId: tenantId)
            };

            // Wait for the files to be uploaded and print the results.
            // If you only care about all files being uploaded and not the order, you can use Task.WhenAll instead.
            var firstUploadedTask = await Task.WhenAny(uploadTasks);
            uploadTasks.Remove(firstUploadedTask);
            var firstUploadedFile = firstUploadedTask.Result;

            Assert.IsType<FileUploadInfo>(firstUploadedFile);
            Assert.True(bigFileName == firstUploadedFile.Name || smallFileName == firstUploadedFile.Name);
            Assert.True(51200 == firstUploadedFile.Size || 10485760 == firstUploadedFile.Size);

            _output.WriteLine("First uploaded file:");
            _output.WriteJson(firstUploadedFile);

            var secondUploadedTask = await Task.WhenAny(uploadTasks);
            var secondUploadedFile = secondUploadedTask.Result;

            Assert.IsType<FileUploadInfo>(firstUploadedFile);
            Assert.True(bigFileName == secondUploadedFile.Name || smallFileName == secondUploadedFile.Name);
            Assert.True(51200 == secondUploadedFile.Size || 10485760 == secondUploadedFile.Size);

            _output.WriteLine("Second uploaded file:");
            _output.WriteJson(secondUploadedFile);
        }
    }
}
