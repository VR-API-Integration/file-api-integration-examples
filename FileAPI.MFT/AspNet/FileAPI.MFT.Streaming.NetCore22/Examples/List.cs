using FileAPI.MFT.Utils;
using Ftaas.Sdk.Base;
using System;
using System.Linq;
using System.Threading.Tasks;
using Xunit;
using Xunit.Abstractions;

namespace FileAPI.MFT.Streaming.NetCore22.Examples
{
    public class List : Startup
    {
        private readonly ITestOutputHelper _output;

        public List(ITestOutputHelper output)
        {
            _output = output;
        }

        [Fact]
        public async Task ListAvailableFilesWithOneHugeCall()
        {
            // The files are retrieved paginated, so if you want to retrieve all the files, you have two options:
            //     1) Do only one call with a huge page size.
            //     2) Do several calls with more manageable page size.
            // Depending on your requirements, you can choose between any of theses options.
            //
            // In this example it's shown how to do the first option: do only one call to retrieve all the available files.

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.

            #endregion

            _output.WriteTittle("Executing Streaming.SDK example: List available files with one call");

            // Configure the list.
            var pagination = new Pagination
            {
                PageIndex = 0,
                PageSize = 1000 // Maximum value. If you have more files than this amount, you will need to use the second option instead.
            };

            // List the files.
            var listResult = await Streaming.GetAvailableFilesAsync(pagination, tenantId: tenantId);

            Assert.IsType<PaginatedItems<FileInfo>>(listResult);

            // Print the result.
            _output.WriteLine("Available files:");
            _output.WriteJsonPaginatedItemsWithoutData(listResult);
        }

        [Fact]
        public async Task ListAvailableFilesWithSeveralSmallCalls()
        {
            // The files are retrieved paginated, so if you want to retrieve all the files, you have two options:
            //     1) Do only one call with a huge page size.
            //     2) Do several calls with more manageable page size.
            // Depending on your requirements, you can choose between any of theses options.
            // In this example it's shown how to do the second option: do several calls to retrieve all the available files.

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.

            #endregion

            _output.WriteTittle("Executing Streaming.SDK example: List available files with several small calls");

            // Configure the list.
            // Every call will retrieve 20 files.
            var pagination = new Pagination
            {
                PageIndex = 0,
                PageSize = 20
            };

            // List the files. Do several calls to the SDK until all files are retrieved.
            PaginatedItems<FileInfo> portionListResult;
            bool areAllFilesRetrieved;
            do
            {
                portionListResult = await Streaming.GetAvailableFilesAsync(pagination, tenantId: tenantId);

                Assert.IsType<PaginatedItems<FileInfo>>(portionListResult);

                _output.WriteLine($"Call {pagination.PageIndex + 1} (PageSize = {pagination.PageSize}):");
                _output.WriteJsonPaginatedItemsWithoutData(portionListResult);

                areAllFilesRetrieved = !portionListResult.Data.Any();
                pagination.PageIndex++;
            } while (!areAllFilesRetrieved);
        }

        [Fact]
        public async Task ListFilesFilteredByUploadDate()
        {
            // For the sake of readability, in this test instead of retreiving all files, we will just retrieve some of them.
            // It's possible to filter by upload date, status and business type.
            // For a better understanding of the filters, please review this link:
            // https://raetwiki.atlassian.net/wiki/spaces/SGW/pages/1274840537/Search+for+Files

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.

            #endregion

            _output.WriteTittle("Executing Streaming.SDK example: List filtered files");

            // Configure the list.
            var pagination = new Pagination
            {
                PageIndex = 0,
                PageSize = 3
            };

            // UploadDate filter. It will show all files that were uploaded between 2020-05-01 (00:00) and 2020-06-01 (00:00)
            var lowerDate = $"{new DateTime(2020, 05, 01).ToUniversalTime():yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'}";
            var higherDate = $"{new DateTime(2020, 06, 01).ToUniversalTime():yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'}";
            var filter = $"UploadDate ge {lowerDate} and UploadDate le {higherDate}";

            // List the files.
            var listResult = await Streaming.GetAvailableFilesAsync(pagination, filter: filter, tenantId: tenantId);

            Assert.IsType<PaginatedItems<FileInfo>>(listResult);
            Assert.DoesNotContain(listResult.Data, fileInfo => fileInfo.UploadDate < DateTime.Parse(lowerDate));
            Assert.DoesNotContain(listResult.Data, fileInfo => fileInfo.UploadDate > DateTime.Parse(higherDate));

            // Print the result.
            _output.WriteLine($"Available files that were uploaded between {lowerDate} and {higherDate}:");
            _output.WriteJson(listResult);
        }

        [Fact]
        public async Task ListFilesFilteredByUploadDateAndStatus()
        {
            // For the sake of readability, in this test instead of retreiving all files, we will just retrieve some of them.
            // It's possible to filter by upload date, status and business type.
            // For a better understanding of the filters, please review this link:
            // https://raetwiki.atlassian.net/wiki/spaces/SGW/pages/1274840537/Search+for+Files

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.

            #endregion

            _output.WriteTittle("Executing Streaming.SDK example: List filtered files");

            // Configure the list.
            var pagination = new Pagination
            {
                PageIndex = 0,
                PageSize = 3
            };

            // UploadDate filter. It will show all files that were uploaded between 2020-05-01 (00:00) and 2020-06-01 (00:00)
            // and has been already downloaded.
            var lowerDate = $"{new DateTime(2020, 05, 01).ToUniversalTime():yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'}";
            var higherDate = $"{new DateTime(2020, 06, 01).ToUniversalTime():yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'}";
            var filter = $"UploadDate ge {lowerDate} and UploadDate le {higherDate} and Status eq 'downloaded'";

            // List the files.
            var listResult = await Streaming.GetAvailableFilesAsync(pagination, filter: filter, tenantId: tenantId);

            Assert.IsType<PaginatedItems<FileInfo>>(listResult);
            Assert.DoesNotContain(listResult.Data, fileInfo => fileInfo.UploadDate < DateTime.Parse(lowerDate));
            Assert.DoesNotContain(listResult.Data, fileInfo => fileInfo.UploadDate > DateTime.Parse(higherDate));

            // Print the result.
            _output.WriteLine($"Downloaded files that were uploaded between {lowerDate} and {higherDate}:");
            _output.WriteJson(listResult);
        }

        [Fact]
        public async Task ListFilesSortedByUploadDate()
        {
            // For the sake of readability, in this test instead of retreiving all files, we will just retrieve some of them.
            // It's possible to sort by upload date, status and business type.
            // For a better understanding of the sorting, please review this link:
            // https://community.raet.com/developers/w/mft-api/2015/list-available-files

            #region Custom parameters

            var tenantId = "MyTenantId"; // Only necessary for multi-tenant token.

            #endregion

            _output.WriteTittle("Executing Streaming.SDK example: List files sorted by the upload date");

            // Configure the list.
            var pagination = new Pagination
            {
                PageIndex = 0,
                PageSize = 3
            };

            // Sorting. It will sort the files by upload date, ascending.
            var orderby = $"UploadDate asc";

            // List the files.
            var listResult = await Streaming.GetAvailableFilesAsync(pagination, orderBy: orderby, tenantId: tenantId);

            Assert.IsType<PaginatedItems<FileInfo>>(listResult);
            var expectedList = listResult.Data.OrderBy(fileInfo => fileInfo.UploadDate);
            Assert.True(expectedList.SequenceEqual(listResult.Data), "Files were not retrieved in the specified order.");

            // Print the result.
            _output.WriteLine($"Available files sorted by upload date, ascending:");
            _output.WriteJson(listResult);
        }
    }
}
