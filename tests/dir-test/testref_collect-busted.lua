local eq = MiniTest.expect.equality

describe('describe()/it()', function()
  describe('nested', function()
    it('Case 1', function() end)
    it('Case 2', function() end)
  end)

  it('Case 3', function() end)
end)

describe('setup()/teardown()', function()
  local n = 0

  describe('nested', function()
    setup(function() n = n + 1 end)
    it('setup() works', function() eq(n, 1) end)
    teardown(function() n = n + 1 end)
  end)

  it('teardown() works', function() eq(n, 2) end)
end)

describe('before_each()/after_each()', function()
  local n, m = 0, 0

  before_each(function() n = n + 1 end)
  after_each(function() m = m + 1 end)

  describe('nested', function()
    describe('nested 2', function()
      it('work', function() eq({ n, m }, { 1, 0 }) end)
    end)
    it('work 2', function() eq({ n, m }, { 2, 1 }) end)
    it('work 3', function() eq({ n, m }, { 3, 2 }) end)
  end)

  it('work 4', function() eq({ n, m }, { 4, 3 }) end)
end)

describe('MiniTest.skip()', function()
  it('works', function() MiniTest.skip() end)
end)

describe('MiniTest.finally()', function()
  local n = 0

  it('no error', function()
    MiniTest.finally(function() n = n + 1 end)
    eq(n, 0)
  end)

  it('works with no error', function() eq(n, 1) end)

  it('with error', function()
    MiniTest.finally(function() n = n + 1 end)
    error('Some error')
  end)

  it('works with error', function() eq(n, 2) end)
end)
