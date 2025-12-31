---@class easy-dotnet.test.Client
---@field _client easy-dotnet.rpc.Client
---@field test_run fun(self: easy-dotnet.test.Client, request: easy-dotnet.test.RunRequest, cb?: fun(res: easy-dotnet.test.RunResult), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request running multiple tests for MTP
---@field test_discover fun(self: easy-dotnet.test.Client, request: easy-dotnet.test.DiscoverRequest, cb?: fun(res: easy-dotnet.test.DiscoveredTest[]), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request test discovery for MTP
---@field set_run_settings fun(self: easy-dotnet.test.Client)

local M = {}
M.__index = M

--- Constructor
---@param client easy-dotnet.rpc.Client
---@return easy-dotnet.test.Client
function M.new(client)
  local self = setmetatable({}, M)
  self._client = client
  return self
end

---@class easy-dotnet.test.DiscoveredTest
---@field id string
---@field namespace? string
---@field name string
---@field displayName string
---@field filePath string
---@field lineNumber? integer

---@class easy-dotnet.test.DiscoverRequest
---@field projectPath string
---@field targetFrameworkMoniker string
---@field configuration string

function M:test_discover(request, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  return helper.create_enumerate_rpc_call({
    client = self._client,
    job = nil,
    method = "test/discover",
    params = request,
    cb = cb,
    on_yield = nil,
    on_crash = opts.on_crash,
  })()
end

---@class easy-dotnet.test.RunRequestNode
---@field uid string Unique test run identifier
---@field displayName string Human-readable name for the run

---@class easy-dotnet.test.RunRequest
---@field projectPath string
---@field targetFrameworkMoniker string
---@field configuration string
---@field filter? table<easy-dotnet.test.RunRequestNode>

--- @class easy-dotnet.test.RunResult
--- @field id string
--- @field stackTrace string[] | nil
--- @field message string[] | nil
--- @field outcome easy-dotnet.test.runner.Result
--- @field stdOut string[] | nil

function M:test_run(request, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  return helper.create_enumerate_rpc_call({
    client = self._client,
    job = nil,
    method = "test/run",
    params = request,
    ---@param res easy-dotnet.test.RunResult[]
    cb = function(res)
      local stackTrace_pending = #res
      local stdOut_pending = #res

      local function done()
        if stackTrace_pending == 0 and stdOut_pending == 0 then
          if cb then cb(res) end
        end
      end
      done()

      for _, value in ipairs(res) do
        ---@diagnostic disable-next-line: undefined-field
        if value.stackTrace and value.stackTrace.token then
          ---@diagnostic disable-next-line: undefined-field
          self._client:request_property_enumerate(value.stackTrace.token, nil, function(trace)
            value.stackTrace = trace
            stackTrace_pending = stackTrace_pending - 1
            done()
          end)
        end

        ---@diagnostic disable-next-line: undefined-field
        if value.stdOut and value.stdOut.token then
          ---@diagnostic disable-next-line: undefined-field
          self._client:request_property_enumerate(value.stdOut.token, nil, function(output)
            value.stdOut = output
            stdOut_pending = stdOut_pending - 1
            done()
          end)
        end
      end
    end,
    on_yield = nil,
    on_crash = opts.on_crash,
  })()
end

function M:set_run_settings() self._client.notify("test/set-project-run-settings", {}) end

return M
