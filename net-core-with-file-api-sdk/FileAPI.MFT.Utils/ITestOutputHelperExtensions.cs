using Ftaas.Sdk.Base;
using Newtonsoft.Json;
using System.Collections.Generic;
using System.Linq;
using Xunit.Abstractions;

namespace FileAPI.MFT.Utils
{
    public static class ITestOutputHelperExtensions
    {
        public static void WriteJson(this ITestOutputHelper output, object value)
        {
            output.WriteLine(JsonConvert.SerializeObject(value, Formatting.Indented));
        }
        public static void WriteJsonPaginatedItemsWithoutData<T>(this ITestOutputHelper output, PaginatedItems<T> value)
        {
            var truncatedValue = new PaginatedItems<string>
            {
                Data = new List<string> { $"Returned files: {value.Data.Count()}. They are not shown in the tests because if they are too much the readability would be bad." },
                PageIndex = value.PageIndex,
                PageSize = value.PageSize,
                Count = value.Count
            };

            output.WriteLine(JsonConvert.SerializeObject(truncatedValue, Formatting.Indented));
        }

        public static void WriteTittle(this ITestOutputHelper output, string value)
        {
            output.WriteLine("=======================================================");
            output.WriteLine(value);
            output.WriteLine("=======================================================");
        }
    }
}
