local utils = require('../lua/utils')

describe('utils', function()
    it('split', function()
        assert.same(utils.split("a b c", " "), { "a", "b", "c" })
    end)
    it('get_absdir_view', function()
        assert.same(utils.get_absdir_view("/usr/bin/"), "/usr/bin/")
        assert.same(utils.get_absdir_view("/usr/bin/", "/usr"), "~/bin/")
        assert.same(utils.get_absdir_view("/"), "/")
    end)
    it('is_array', function()
        assert.same(utils.is_array("aaa"), false)
        assert.same(utils.is_array({ 1, 2, 3 }), true)
        assert.same(utils.is_array({ key = "value" }), false)
    end)
end)
