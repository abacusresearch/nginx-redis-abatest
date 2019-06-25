-- test script

ngx.log(ngx.ERR, "AbaVM: " .. ngx.var.vm)
ngx.exit(ngx.HTTP_FORBIDDEN);
