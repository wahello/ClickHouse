#include "config.h"

#if USE_H3

#include <Columns/ColumnsNumber.h>
#include <DataTypes/DataTypesNumber.h>
#include <Functions/FunctionFactory.h>
#include <Functions/IFunction.h>
#include <IO/WriteHelpers.h>
#include <Common/typeid_cast.h>
#include <base/range.h>

#include <constants.h>
#include <h3api.h>


namespace DB
{
namespace ErrorCodes
{
extern const int ILLEGAL_TYPE_OF_ARGUMENT;
extern const int ILLEGAL_COLUMN;
extern const int INCORRECT_DATA;
}

namespace
{

class FunctionH3CellAreaRads2 final : public IFunction
{
public:
    static constexpr auto name = "h3CellAreaRads2";

    static FunctionPtr create(ContextPtr) { return std::make_shared<FunctionH3CellAreaRads2>(); }

    std::string getName() const override { return name; }

    size_t getNumberOfArguments() const override { return 1; }
    bool useDefaultImplementationForConstants() const override { return true; }
    bool isSuitableForShortCircuitArgumentsExecution(const DataTypesWithConstInfo & /*arguments*/) const override { return false; }

    DataTypePtr getReturnTypeImpl(const DataTypes & arguments) const override
    {
        const auto * arg = arguments[0].get();
        if (!WhichDataType(arg).isUInt64())
            throw Exception(
                ErrorCodes::ILLEGAL_TYPE_OF_ARGUMENT,
                "Illegal type {} of argument {} of function {}. Must be UInt64",
                arg->getName(), 1, getName());

        return std::make_shared<DataTypeFloat64>();
    }

    DataTypePtr getReturnTypeForDefaultImplementationForDynamic() const override
    {
        return std::make_shared<DataTypeFloat64>();
    }

    ColumnPtr executeImpl(const ColumnsWithTypeAndName & arguments, const DataTypePtr &, size_t input_rows_count) const override
    {
        auto non_const_arguments = arguments;
        for (auto & argument : non_const_arguments)
            argument.column = argument.column->convertToFullColumnIfConst();

        const auto * column = checkAndGetColumn<ColumnUInt64>(non_const_arguments[0].column.get());
        if (!column)
            throw Exception(
                ErrorCodes::ILLEGAL_COLUMN,
                "Illegal type {} of argument {} of function {}. Must be UInt64",
                arguments[0].type->getName(),
                1,
                getName());
        const auto & data = column->getData();

        auto dst = ColumnVector<Float64>::create();
        auto & dst_data = dst->getData();
        dst_data.resize(input_rows_count);

        for (size_t row = 0; row < input_rows_count; ++row)
        {
            const UInt64 index = data[row];

            CellBoundary boundary{};
            auto err = cellToBoundary(index, &boundary);
            if (err)
                throw Exception(ErrorCodes::INCORRECT_DATA, "Incorrect H3 index: {}, error: {}", index, err);

            Float64 res = cellAreaRads2(index);
            dst_data[row] = res;
        }

        return dst;
    }
};

}

REGISTER_FUNCTION(H3CellAreaRads2)
{
    factory.registerFunction<FunctionH3CellAreaRads2>();
}

}

#endif
