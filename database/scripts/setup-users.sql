-- create users
create user app_cms;
create user app_cms_authenticator noinherit;
create user app_cms_visitor;

-- relate users
grant app_cms_visitor to app_cms_authenticator;
