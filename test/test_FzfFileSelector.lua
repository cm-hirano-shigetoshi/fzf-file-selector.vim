local utils = require('../lua/utils')

describe('utils', function()
    it('split', function()
        assert.same(utils.split("a b c", " "), { "a", "b", "c" })
    end)
end)
