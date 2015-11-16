---------
-- Module for reading/writing request/response cookies.
-- This module exports single function, the module's constructor.
--
-- **Example:**
--     local Cookies = require 'ngx-oauth.Cookies'
--
--     cookies = Cookies(conf)
--     cookies.add_token(token)
--
-- @alias self

local util = require 'ngx-oauth/util'

local min  = math.min
local imap = util.imap
local par  = util.partial
local pipe = util.pipe

local COOKIE_ACCESS_TOKEN  = 'oauth_access_token'
local COOKIE_REFRESH_TOKEN = 'oauth_refresh_token'
local COOKIE_USERNAME      = 'oauth_username'
local COOKIE_EMAIL         = 'oauth_email'

local ALL_COOKIES = { COOKIE_ACCESS_TOKEN, COOKIE_REFRESH_TOKEN, COOKIE_USERNAME, COOKIE_EMAIL }


--- Creates a new Cookies "object" with the given configuration.
--
-- @function __call
-- @tparam table conf The configuration (see @{ngx-oauth.config}).
-- @tparam {encrypt=func,decrypt=func} crypto The crypto module to use
--   (default: @{ngx-oauth.crypto}).
-- @return An initialized Cookies module.
return function (conf, crypto)
  if not crypto then
    crypto = require 'ngx-oauth/crypto'
  end

  local self = {}
  local refresh_token = nil  -- cached token after decryption

  local encrypt = par(crypto.encrypt, conf.aes_bits, conf.client_secret)
  local decrypt = par(crypto.decrypt, conf.aes_bits, conf.client_secret)

  local function create_cookie (name, value, max_age)
    return util.format_cookie(name, value, {
      version = 1, secure = true, path = conf.cookie_path, max_age = max_age
    })
  end

  local function clear_cookie (name)
    return create_cookie(name, 'deleted', 0)
  end

  --- Writes access token and refresh token (if provided) cookies to the
  -- *response's* `Set-Cookie` header.
  --
  -- @tparam {access_token=string,expires_in=int,refresh_token=(string|nil)} token
  self.add_token = function(token)
    local cookies = {
      create_cookie(COOKIE_ACCESS_TOKEN, token.access_token, min(token.expires_in, conf.max_age))
    }
    if token.refresh_token then
      table.insert(cookies,
        create_cookie(COOKIE_REFRESH_TOKEN, encrypt(token.refresh_token), conf.max_age))
    end
    util.add_response_cookies(cookies)
  end

  --- Writes userinfo cookies, i.e. username and email, to the *response's*
  -- `Set-Cookie` header.
  --
  -- @tparam {username=string,email=string} userinfo
  self.add_userinfo = function(userinfo)
    util.add_response_cookies {
      create_cookie(COOKIE_USERNAME, userinfo.username, conf.max_age),
      create_cookie(COOKIE_EMAIL, userinfo.email, conf.max_age)
    }
  end

  --- Clears all cookies managed by this module, i.e. adds them to the
  -- *response's* `Set-Cookie` header with value `deleted` and `Max-Age=0`.
  --
  -- @function clear_all
  self.clear_all = pipe {
    par(imap, clear_cookie, ALL_COOKIES),
    util.add_response_cookies
  }

  --- Reads an access token from the *request's* cookies.
  --
  -- @function get_access_token
  -- @treturn string|nil An access token, or `nil` if not set.
  self.get_access_token = par(util.get_cookie, COOKIE_ACCESS_TOKEN)

  --- Reads a refresh token from the *request's* cookies.
  -- @treturn string|nil A decrypted refresh token, or `nil` if not set.
  self.get_refresh_token = function()
    if not refresh_token then
      local value = util.get_cookie(COOKIE_REFRESH_TOKEN)
      if value then refresh_token = decrypt(value) end
    end
    return refresh_token
  end

  --- Reads an username from the *request's* cookies.
  --
  -- @function get_username
  -- @treturn string|nil An username, or `nil` if not set.
  self.get_username = par(util.get_cookie, COOKIE_USERNAME)

  return self
end