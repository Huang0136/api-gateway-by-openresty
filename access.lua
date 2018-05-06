-- 不需要登录的url
-- /etcd-test/login,登录接口
-- /etcd-test/no-need-login,测试用
-- ...
local no_need_login_urls = {"/etcd-test/login","/etcd-test/no-need-login"}

-- 获取uri
local uri = ngx.var.uri
-- 获取cookie local cookie = ngx.req.get_headers()["Cookie"];
local cookie = ngx.var["cookie_xxx.site-cookie"]

local noCookiePass = false -- 当前url是否不需要登录
for k,v in ipairs(no_need_login_urls) do 
	if uri == v then 
		noCookiePass = true
		break
	end
end 

if noCookiePass then 
	ngx.log(ngx.INFO,"不需要登录的url:",uri,",cookie:",cookie,",",noCookiePass)
else -- 需要认证
	if cookie ~= nil then -- 有cookie
		--  鉴权
		-- redis connection
		local redis = require "resty.redis"
		local cjson = require "cjson"
		local red = redis:new()
		red:set_timeout(1000) -- 1 sec
		
		local ok,err = red:connect("127.0.0.1",6379)
		if not ok then 
			ngx.log(ngx.INFO,"连接redis失败:",err)
			ngx.header.content_type="application/json"
			ngx.say("{\"ret_code\":1002,\"err_msg\":\"连接redis失败！"..err.."\"}")
			ngx.exit(ngx.HTTP_OK)
		end 
		
		-- redis auth
		local res,err = red:auth("*****")
		if not res then 
			ngx.log(ngx.INFO,"redis认证失败:",err)
			ngx.header.content_type="application/json"
			ngx.say("{\"ret_code\":1003,\"err_msg\":\"redis认证失败！"..err.."\"}")
			ngx.exit(ngx.HTTP_OK)
		end 
		
		-- get session from redis
		local res ,err = red:get(cookie)
		if not res then 
			ngx.log(ngx.INFO,"redis get失败:",err)
			ngx.header.content_type="application/json"
			ngx.say("{\"ret_code\":1003,\"err_msg\":\"redis get失败！"..err.."\"}")
			ngx.exit(ngx.HTTP_OK)
		end 
		if res == ngx.null then
			ngx.log(ngx.INFO,"session不存在:"..cookie)
			ngx.header.content_type="application/json"
			ngx.say("{\"ret_code\":1003,\"err_msg\":\"session不存在:"..cookie.."\"}")
			ngx.exit(ngx.HTTP_OK)
		end 

		-- string to json
		local unjson = cjson.decode(res)

		-- TODO 鉴权逻辑:
		-- 1.根据uri获取该资源被哪些role(角色)拥有，(restful api -> resouce url)
		-- 2.根据unjson获取当前用户拥有什么role(角色)
		-- 根据1和2判断当前用户是否拥有权限

		ngx.log(ngx.INFO,"有登录态,uri:",uri,",cookie:",cookie,",redis session::",unjson["username"],",",unjson["age"],"::");

	else -- 没有cookie
		ngx.log(ngx.INFO,"用户未登录！uri:",uri)
		ngx.header.content_type="application/json"
		ngx.say("{\"ret_code\":1003,\"err_msg\":\"用户未登录！\"}")
		ngx.exit(ngx.HTTP_OK)
	end
end
