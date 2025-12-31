local jobs = require("easy-dotnet.ui-modules.jobs")

---@class easy-dotnet.msbuild.Client
---@field _client easy-dotnet.rpc.Client
---@field msbuild_query_properties fun(self: easy-dotnet.msbuild.Client, request: easy-dotnet.msbuild.QueryProjectPropertiesRequest, cb?: fun(res: easy-dotnet.msbuild.ProjectProperties), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request msbuild
---@field msbuild_list_project_reference fun(self: easy-dotnet.msbuild.Client, targetPath: string, cb?: fun(res: string[]), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request project references
---@field msbuild_list_package_reference fun(self: easy-dotnet.msbuild.Client, targetPath: string, target_framework: string, cb?: fun(res: easy-dotnet.msbuild.PackageReference[]), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request package references
---@field msbuild_add_project_reference fun(self: easy-dotnet.msbuild.Client, projectPath: string, targetPath: string, cb?: fun(success: boolean), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request project references
---@field msbuild_remove_project_reference fun(self: easy-dotnet.msbuild.Client, projectPath: string, targetPath: string, cb?: fun(success: boolean), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request project references
---@field msbuild_build fun(self: easy-dotnet.msbuild.Client, request: easy-dotnet.msbuild.BuildRequest, cb?: fun(res: easy-dotnet.msbuild.BuildResult), opts?: easy-dotnet.rpc.GenericCallOptions): easy-dotnet.rpc.CallHandle # Request msbuild

local M = {}
M.__index = M

--- Constructor
---@param client easy-dotnet.rpc.Client
---@return easy-dotnet.msbuild.Client
function M.new(client)
  local self = setmetatable({}, M)
  self._client = client
  return self
end

---@class easy-dotnet.msbuild.PackageReference
---@field id string
---@field requestedVersion string
---@field resolvedVersion string

---@class easy-dotnet.msbuild.ProjectProperties
---@field projectName string
---@field language string
---@field outputPath? string
---@field outputType? string
---@field targetExt? string
---@field assemblyName? string
---@field targetFramework? string
---@field targetFrameworks? string[]
---@field isTestProject boolean
---@field isWebProject boolean
---@field isWorkerProject boolean
---@field userSecretsId? string
---@field testingPlatformDotnetTestSupport boolean
---@field targetPath? string
---@field generatePackageOnBuild boolean
---@field isPackable boolean
---@field langVersion? string
---@field rootNamespace? string
---@field packageId? string
---@field nugetVersion? string
---@field version? string
---@field packageOutputPath? string
---@field isMultiTarget boolean
---@field isNetFramework boolean
---@field useIISExpress boolean
---@field runCommand string
---@field buildCommand string
---@field testCommand string

---@class easy-dotnet.msbuild.QueryProjectPropertiesRequest
---@field targetPath string
---@field configuration? string
---@field targetFramework? string

function M:msbuild_query_properties(request, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  local proj_name = vim.fn.fnamemodify(request.targetPath, ":t:r")
  return helper.create_rpc_call({
    client = self._client,
    job = { name = "Loading " .. proj_name, on_success_text = proj_name .. " loaded", on_error_text = "Failed to load " .. proj_name, timeout = -1 },
    cb = cb,
    on_crash = opts.on_crash,
    method = "msbuild/project-properties",
    params = { request = request },
  })()
end

function M:msbuild_list_project_reference(targetPath, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  return helper.create_rpc_call({
    client = self._client,
    job = nil,
    cb = cb,
    on_crash = opts.on_crash,
    method = "msbuild/list-project-reference",
    params = { projectPath = targetPath },
  })()
end

function M:msbuild_add_project_reference(projectPath, targetPath, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  return helper.create_rpc_call({
    client = self._client,
    job = nil,
    cb = cb,
    on_crash = opts.on_crash,
    method = "msbuild/add-project-reference",
    params = { projectPath = projectPath, targetPath = targetPath },
  })()
end

---@param projectPath string
---@param targetPath string
---@param cb? fun(success: boolean)
---@param opts? easy-dotnet.rpc.GenericCallOptions
---@return easy-dotnet.rpc.CallHandle
function M:msbuild_remove_project_reference(projectPath, targetPath, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  return helper.create_rpc_call({
    client = self._client,
    job = nil,
    cb = cb,
    on_crash = opts.on_crash,
    method = "msbuild/remove-project-reference",
    params = { projectPath = projectPath, targetPath = targetPath },
  })()
end

---@class easy-dotnet.msbuild.BuildRequest
---@field targetPath string
---@field targetFramework? string
---@field configuration? string
---@field buildArgs? string

---@class easy-dotnet.msbuild.Diagnostic
---@field code string
---@field columnNumber integer
---@field filePath string
---@field lineNumber integer
---@field message string
---@field type "error" | "warning"
---@field project string | nil

---@class easy-dotnet.msbuild.BuildResult
---@field errors easy-dotnet.msbuild.Diagnostic[]
---@field warnings easy-dotnet.msbuild.Diagnostic[]
---@field success boolean

function M:msbuild_build(request, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  local finished = jobs.register_job({ name = "Building...", on_error_text = "Build failed", on_success_text = "Built successfully", timeout = -1 })
  return helper.create_rpc_call({
    client = self._client,
    job = nil,
    cb = function(result)
      local pending = 2

      local function done()
        if pending == 0 then
          finished(result.success)
          if cb then cb(result) end
        end
      end

      if result.warnings and result.warnings.token then
        self._client:request_property_enumerate(result.warnings.token, nil, function(warnings)
          result.warnings = warnings
          pending = pending - 1
          done()
        end)
      end

      if result.errors and result.errors.token then
        self._client:request_property_enumerate(result.errors.token, nil, function(errors)
          result.errors = errors
          pending = pending - 1
          done()
        end)
      end
    end,
    on_crash = opts.on_crash,
    method = "msbuild/build",
    params = { request = request },
  })()
end

function M:msbuild_list_package_reference(target_path, target_framework, cb, opts)
  local helper = require("easy-dotnet.rpc.dotnet-client")
  opts = opts or {}
  return helper.create_enumerate_rpc_call({
    client = self._client,
    job = nil,
    method = "msbuild/list-package-reference",
    params = { projectPath = target_path, targetFramework = target_framework },
    cb = cb,
    on_yield = nil,
    on_crash = opts.on_crash,
  })()
end

return M
