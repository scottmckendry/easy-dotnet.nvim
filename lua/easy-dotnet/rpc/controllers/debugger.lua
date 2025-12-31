---@class easy-dotnet.debugger.rpc.Client
---@field _client easy-dotnet.rpc.Client
---@field debugger_start fun(self: easy-dotnet.debugger.rpc.Client, request: easy-dotnet.debugger.rpc.StartRequest, cb?: fun(res: easy-dotnet.debugger.rpc.StartResponse), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle

local M = {}
M.__index = M

--- Constructor
---@param client easy-dotnet.rpc.Client
---@return easy-dotnet.debugger.rpc.Client
function M.new(client)
  local self = setmetatable({}, M)
  self._client = client
  return self
end

---@class easy-dotnet.debugger.rpc.StartRequest
---@field targetPath string
---@field targetFramework string?
---@field configuration string?
---@field launchProfileName string?

---@class easy-dotnet.debugger.rpc.StartResponse
---@field success boolean
---@field port integer | nil

function M:debugger_start(request, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  return helper.create_rpc_call({
    client = self._client,
    job = { name = "Starting debugger", on_success_text = "Debugger attached", on_error_text = "Failed to start debugger" },
    cb = cb,
    on_crash = opts.on_crash,
    method = "debugger/start",
    params = { request = request },
  })()
end

return M
