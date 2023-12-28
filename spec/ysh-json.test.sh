## oils_failures_allowed: 4
## tags: dev-minimal

#### usage errors

json read zz
echo status=$?

json write

## status: 3
## STDOUT:
status=2
## END

#### json write STRING
shopt --set parse_proc

json write ('foo')
var s = 'foo'
json write (s)
## STDOUT:
"foo"
"foo"
## END

#### json write ARRAY
json write (:|foo.cc foo.h|)
json write --indent 0 (['foo.cc', 'foo.h'])
## STDOUT:
[
  "foo.cc",
  "foo.h"
]
[
"foo.cc",
"foo.h"
]
## END

#### json write Dict
json write ({k: 'v', k2: [4, 5]})

json write ([{k: 'v', k2: 'v2'}, {}])

## STDOUT:
{
  "k": "v",
  "k2": [
    4,
    5
  ]
}
[
  {
    "k": "v",
    "k2": "v2"
  },
  {

  }
]
## END

#### json write compact format
shopt --set parse_proc

# TODO: ORDER of keys should be PRESERVED
var mydict = {name: "bob", age: 30}

json write --pretty=0 (mydict)
# ignored
json write --pretty=F --indent 4 (mydict)
## STDOUT:
{"name":"bob","age":30}
{"name":"bob","age":30}
## END

#### json write in command sub
shopt -s oil:all  # for echo
var mydict = {name: "bob", age: 30}
json write (mydict)
var x = $(json write (mydict))
echo $x
## STDOUT:
{
  "name": "bob",
  "age": 30
}
{
  "name": "bob",
  "age": 30
}
## END

#### json read passed invalid args

# EOF
json read
echo status=$?

json read 'z z'
echo status=$?

json read a b c
echo status=$?

## STDOUT:
status=1
status=2
status=2
## END

#### json read uses $_reply var

echo '{"age": 42}' | json read
json write (_reply)

## STDOUT:
{
  "age": 42
}
## END

#### json read with redirect
echo '{"age": 42}'  > $TMP/foo.txt
json read (&x) < $TMP/foo.txt
pp cell :x
## STDOUT:
x = (Cell exported:F readonly:F nameref:F val:(value.Dict d:[Dict age (value.Int i:42)]))
## END

#### json read at end of pipeline (relies on lastpipe)
echo '{"age": 43}' | json read (&y)
pp cell y
## STDOUT:
y = (Cell exported:F readonly:F nameref:F val:(value.Dict d:[Dict age (value.Int i:43)]))
## END

#### invalid JSON
echo '{' | json read (&y)
echo pipeline status = $?
pp cell y
## status: 1
## STDOUT:
pipeline status = 1
## END

#### json write expression
json write --pretty=0 ([1,2,3])
echo status=$?

json write (5, 6)  # to many args
echo status=$?

## status: 3
## STDOUT:
[1,2,3]
status=0
## END

#### json write evaluation error

#var block = ^(echo hi)
#json write (block) 
#echo status=$?

# undefined var
json write (a) 
echo 'should have failed'

## status: 1
## STDOUT:
## END

#### json write of List in cycle

var L = [1, 2, 3]
setvar L[0] = L

shopt -s ysh:upgrade
fopen >tmp.txt {
  pp line (L)
}
fgrep -n -o '[ ...' tmp.txt

json write (L)
echo 'should have failed'

## status: 1
## STDOUT:
1:[ ...
## END

#### json write of Dict in cycle

var d = {}
setvar d.k = d

shopt -s ysh:upgrade
fopen >tmp.txt {
  pp line (d)
}
fgrep -n -o '{ ...' tmp.txt

json write (d)
echo 'should have failed'

## status: 1
## STDOUT:
1:{ ...
## END

#### j8 write

# TODO: much better tests
j8 write ([3, "foo"])

## STDOUT:
[
  3,
  "foo"
]
## END


#### j8 write bytes vs unicode string

u=$'mu \u03bc \x01 \" \\ \b\f\n\r\t'
u2=$'\x01\x1f'  # this is a valid unicode string

b=$'\xff'  # this isn't valid unicode

j8 write (u)
j8 write (u2)

j8 write (b)

## STDOUT:
"mu μ \u0001 \" \\ \b\f\n\r\t"
"\u0001\u001f"
b"\yff"
## END

#### Escaping uses \u0001 in "", but \u{1} in b""

s1=$'\x01'
s2=$'\x01\xff\x1f'  # byte string

j8 write (s1)
j8 write (s2)

## STDOUT:
"\u0001"
b"\u{1}\yff\u{1f}"
## END


#### j8 read

# Avoid conflict on stdin from spec test framework?

$SH $REPO_ROOT/spec/testdata/j8-read.sh

## STDOUT:
(Dict)   {}
(List)   []
(List)   [42]
(List)   [true,false]
(Dict)   {"k":"v"}
(Dict)   {"k":null}
(Dict)   {"k":1,"k2":2}
(Dict)   {"k":{"k2":null}}
(Dict)   {"k":{"k2":"v2"},"k3":"backslash \\ \" \n line 2 μ "}
## END

#### j8 round trip

var obj = [42, 1.5, null, true, "hi"]

j8 write --pretty=F (obj) > j

cat j

j8 read < j

j8 write (_reply)

## STDOUT:
[42,1.5,null,true,"hi"]
[
  42,
  1.5,
  null,
  true,
  "hi"
]
## END

#### json round trip (regression)

var d = {
  short: '-v', long: '--verbose', type: null, default: '', help: 'Enable verbose logging'
}

json write (d) | json read

pp line (_reply)

## STDOUT:
(Dict)   {"short":"-v","long":"--verbose","type":null,"default":"","help":"Enable verbose logging"}
## END

#### toJson() toJ8() - TODO: test difference

var obj = [42, 1.5, null, true, "hi"]

echo $[toJson(obj)]
echo $[toJ8(obj)]

## STDOUT:
[42,1.5,null,true,"hi"]
[42,1.5,null,true,"hi"]
## END

#### fromJson() fromJ8() - TODO: test difference

var message ='[42,1.5,null,true,"hi"]'

pp line (fromJson(message))
pp line (fromJ8(message))

## STDOUT:
(List)   [42,1.5,null,true,"hi"]
(List)   [42,1.5,null,true,"hi"]
## END

#### User can handle errors - toJson() toJ8()

var obj = []
call obj->append(obj)

echo $[toJson(obj)]
echo $[toJ8(obj)]

## STDOUT:
[42,1.5,null,true,"hi"]
[42,1.5,null,true,"hi"]
## END

#### User can handle errors - fromJson() fromJ8()

var message ='[42,1.5,null,true,"hi"'

pp line (fromJson(message))
pp line (fromJ8(message))

## STDOUT:
(List)   []
## END

