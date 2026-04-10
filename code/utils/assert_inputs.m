function assert_inputs(varargin)
% ASSERT_INPUTS Flexible input assertion utility.
%
%   assert_inputs('numeric', var, 'nonempty', var, 'size', {var, [M N]})
%
%   Supported checks: 'numeric', 'size', 'nonempty', 'finite', 'positive',
%                     'string', 'struct'

    i = 1;
    while i <= nargin
        check_type = varargin{i};
        i = i + 1;

        switch lower(check_type)
            case 'numeric'
                val = varargin{i}; i = i + 1;
                if ~isnumeric(val)
                    error('assert_inputs:notNumeric', 'Expected numeric input.');
                end

            case 'size'
                args = varargin{i}; i = i + 1;
                val = args{1};
                expected = args{2};
                actual = size(val);
                for d = 1:numel(expected)
                    if ~isnan(expected(d)) && (d > numel(actual) || actual(d) ~= expected(d))
                        error('assert_inputs:sizeMismatch', ...
                            'Size mismatch: expected %s, got %s.', ...
                            mat2str(expected), mat2str(actual));
                    end
                end

            case 'nonempty'
                val = varargin{i}; i = i + 1;
                if isempty(val)
                    error('assert_inputs:empty', 'Input must not be empty.');
                end

            case 'finite'
                val = varargin{i}; i = i + 1;
                if ~all(isfinite(val(:)))
                    error('assert_inputs:notFinite', 'Input must contain only finite values.');
                end

            case 'positive'
                val = varargin{i}; i = i + 1;
                if ~all(val(:) > 0)
                    error('assert_inputs:notPositive', 'Input must be positive.');
                end

            case 'string'
                val = varargin{i}; i = i + 1;
                if ~ischar(val) && ~isstring(val)
                    error('assert_inputs:notString', 'Expected string input.');
                end

            case 'struct'
                val = varargin{i}; i = i + 1;
                if ~isstruct(val)
                    error('assert_inputs:notStruct', 'Expected struct input.');
                end

            otherwise
                error('assert_inputs:unknownCheck', 'Unknown check type: %s', check_type);
        end
    end
end
