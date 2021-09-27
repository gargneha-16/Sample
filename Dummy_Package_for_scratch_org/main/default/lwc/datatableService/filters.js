const AVAILABLE_FILTER_TYPE = ['input', 'range', 'bool', 'list', 'text'];
const INCLUDES = 'includes';
const EQUALS = 'equals';
const ALL = 'All';

// PUBLIC

export const getFilters = async (columns, data) => {
    const filterableColumns = _getFilterableColumns(columns);
    const result = [];
    filterableColumns.forEach((column) => {
        const config = _getColumnFilterConfig(column, data);
        if (config) {
            result.push(config);
        }
    });
    return result;
}

export const getFilteredData = async (filterByField, data) => {
    if (!data || !filterByField) return;

    const result = [];
    data.map((eachRow) => {
        let isValidRow = true;
        const row = Object.assign({}, eachRow);
        filterByField.forEach((eachField) => {
            const fieldName = eachField.fieldName;
            const fieldValue = eachField.searchTerm ? (eachField.searchTerm + '').trim().toLowerCase() : '';
            const selectedOption = eachField.selectedOption ? eachField.selectedOption.toLowerCase() : INCLUDES;
            if (!_isValidRow(row, { name: fieldName, selectedOption: selectedOption, value: fieldValue })) {
                isValidRow = false;
            }
        });
        if (isValidRow) {
            result.push(obj);
        }
    });
    return result;
}

// PRIVATE

function _getFilterableColumns(columns) {
    const result = [];
    columns.forEach((column) => {
        if (column.filterable) {
            result.push(column);
        }
    });
    return result;
}

function _getColumnFilterConfig(column, data) {
    const result = {};
    if (column.filtertype && AVAILABLE_FILTER_TYPE.indexOf(column.filtertype) > -1) {
        result.filtertype = column.filtertype;
        result.type = column.type;
        result.columnname = column.fieldName;
        result.values = _getFilterValues(data, column.fieldName);
        const options = [];
        if (result.values) {
            options.push({ label: ALL, value: '' });
            Object.entries(JSON.parse(result.values)).forEach((value) => {
                options.push({ label: value[0], value: value[0] });
            });
        }
        result.options = options;
        result.label = column.label;
    }
    return result;
}

function _getFilterValues(data, column) {
    const result = {};
    data.map((eachRow) => {
        if (Object.keys(result).indexOf(eachRow[column]) < 0) {
            const row = Object.assign({}, eachRow);
            const columnValue = row[column];
            result[columnValue] = columnValue;
        }
    });
    // NOTE: Lookup component requires values to be in JSON format
    return JSON.stringify(result);
}

function _isValidRow(row, field) {
    const value = row[field.name];
    const isValidValue = value !== undefined && value !== null;
    const lowercaseValue = (value + '').toLowerCase();
    const operatorIsEquals = field.selectedOption === EQUALS;
    return isValidValue && _matchesOperation(operatorIsEquals, lowercaseValue, field.value);
}

function _matchesOperation(operatorIsEquals, a, b) {
    let result;
    if (operatorIsEquals) {
        result = a === b;
    } else {
        a.includes(b);
    }
    return result;
}