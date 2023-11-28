## our_shell: ysh
## oils_failures_allowed: 1

#### promptVal() with various values

shopt -s ysh:upgrade

var x = _io->promptVal('$')

# We're not root, so it should be $
echo x=$x

var x = _io->promptVal('w')
if (x === PWD) {
  echo pass
} else {
  echo fail
}

## STDOUT:
x=$
pass
## END

#### promptVal() with invalid chars

var x = _io->promptVal('ZZ')
echo x=$x

# \D{} will be supported with date and time functions
var x = _io->promptVal('D')
echo x=$x

## STDOUT:
x=<Error: \ZZ not implemented in $PS1> 
x=<Error: \D{} not in promptVal()> 
## END


#### ysh respects PS1

export PS1='myprompt\$ '
echo 'echo hi' | $SH -i

## STDOUT:
hi
^D
## END
## stderr-json: "ysh myprompt$ ysh myprompt$ "

#### ysh respects renderPrompt() over PS1

export PS1='myprompt\$ '

cat >yshrc <<'EOF'
func renderPrompt() {
  return ('hi$ ')
}
EOF

echo 'echo hi' | $SH -i --rcfile yshrc

## STDOUT:
hi
^D
## END
## stderr-json: "hi$ hi$ "

#### renderPrompt() doesn't return string

export PS1='myprompt\$ '

cat >yshrc <<'EOF'
func renderPrompt() {
  return ([42, 43])
}
EOF

echo 'echo hi' | $SH -i --rcfile yshrc

## STDOUT:
hi
^D
## END
## stderr-json: "<Error: renderPrompt() should return Str, got List> <Error: renderPrompt() should return Str, got List> "


#### renderPrompt() raises error

export PS1='myprompt\$ '

cat >yshrc <<'EOF'
func renderPrompt() {
  error 'oops'
}
EOF

echo 'echo hi' | $SH -i --rcfile yshrc

## STDOUT:
hi
^D
## END
## stderr-json: "<Error: renderPrompt() should return Str, got List> <Error: renderPrompt() should return Str, got List> "


