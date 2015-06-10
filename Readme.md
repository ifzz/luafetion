## Lua Fetion

this script can be used to send msg via CMCC to your friend

### Dependencies

[luasocket](https://github.com/diegonehab/luasocket)

[copas](http://keplerproject.github.io/copas/index.html) (already in the repository)

### Usage

1. run the script

``` bash
# "136XXXXXXXX" is your mobile number
# "true" is a debug flag to print more info
lua fetion.lua 136XXXXXXXX true
```

2. CMCC will send you a sms for password, enter it.

3. after login, will ask you to input command

there are 3 commands supported:

**ls**   --> list all your friends. Every friend start with a index like [1] XXX

**send** --> send the msg to some one, the format will be 'send 1 msg_to_send'

**exit** --> logout fetion and exit
