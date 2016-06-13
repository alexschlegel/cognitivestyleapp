# convert an object to a string representation
window.obj2str = (obj, indent=0, recursion_limit=5) ->
    if recursion_limit<0
        '...'
    else if obj? and (typeof obj=='object')
        if obj['toString'] instanceof Function
            obj.toString()
        else
            pre = (if indent>0 then "\n" else "")
            pad = string_pad('',3*indent," ")
            str = []

            for key,val of obj
              str.push "#{pad}#{key}:#{obj2str(val,indent+1,recursion_limit-1)}"

            pre+str.join("\n")
    else
        obj
# get the class of an object
window.get_class = (obj) ->
    if obj? then obj.constructor.name else null
# make a copy of an object
window.copy_object = (x, deep=false) ->
    switch get_class(x)
        when 'Object'
            if deep
                y = {}
                (y[key] = copy_object(val,true)) for key,val of x
                y
            else
                extend_object {}, x
        when 'Array'
            if deep
                (copy_object(val,true) for val in x)
            else
                x.slice(0)
        else
            if (typeof x=='object') and x['copy'] instanceof Function
                x.copy()
            else
                x
# extend an object with the key/value pairs of another object
window.extend_object = (obj1, obj2) ->
    obj1[key] = val for key,val of obj2
    obj1
# merge two objects
window.merge_object = (obj1, obj2) ->
    extend_object copy_object(obj1), obj2
# return and remove an element from an object
window.object_extract = (obj, key) ->
    x = obj[key]
    delete obj[key]
    x
# remove an element from an object
window.object_remove = (obj, key, copy=true) ->
    if copy then obj = copy_object obj
    delete obj[key]
    obj
# fill an object with a value
window.fill_object = (x, value) ->
    if Array.isArray(x)
        obj = {}
        for key in x
            obj[key] = value
        obj
    else
        (x[key]=value) for key of x

#test whether two things are equivalent
window.equals = (x,y) ->
    if Array.isArray(x) and Array.isArray(y)
        if x.length==y.length
            for idx in [0..x.length-1]
                if not equals(x[idx], y[idx])
                    return false
            true
        else
            false
    else
        x==y

# fill an array with a value
window.fill_array = (x, value) ->
    if Array.isArray(x)
        (x[idx]=value) for idx in [0..x.length]
    else
        x = (value for [1..x])
# make sure something is an array
window.force_array = (a) ->
    if a? and not Array.isArray(a) then [a] else a
# find an element in an array
window.find = (x, v, limit=Infinity) ->
    f = []
    
    if limit==0
        return f
    
    for e,i in x when equals(e,v)
        f.push(i)
        if f.length==limit
            break
    
    f
# return the set difference of two arrays
window.set_diff = (x, d) ->
    x = force_array x
    d = force_array d
    e for e in x when find(d, e).length==0
# swap two elements in an array
window.array_swap = (x, idx1, idx2) ->
    [x[idx1], x[idx2]] = [x[idx2], x[idx1]]
    x
# reorder the elements of an array
window.array_reorder = (x, idx) ->
    n = x.length
    x_new = new Array(n)
    for i in [0..n-1]
        x_new[idx[i]] = x[i]
    for i in [0..n-1]
        x[i] = x_new[i]
    x
# pick a random element from an array
window.pick_from = (x) ->
    x = force_array x
    x[random_int(0,x.length-1)]
# randomize the elements of an array
window.array_randomize = (x, rng=Math.random) ->
    idx = x.length - 1
    while idx != 0
        idx_rand = random_int 0, idx, rng
        array_swap x, idx, idx_rand
        idx--
    x

# sum of the elements in an array
window.array_sum = (x, idx_from=0, idx_to=null) ->
    s = 0
    (s += x[idx]) for idx in [idx_from..idx_to ? x.length-1]
    s
# product of the elements in an array
window.array_prod = (x, idx_from=0, idx_to=null) ->
    m = 1
    (m *= x[idx]) for idx in [idx_from..idx_to ? x.length-1]
    m
# mean of the elements in an array
window.array_mean = (x) ->
    array_sum(x)/x.length
# element-wise addition of two arrays
window.array_add = (a, b) ->
    (a[idx]+b[idx] for idx in [0..a.length-1])
# element-wise subtraction of two arrays
window.array_subtract = (a, b) ->
    (a[idx]-b[idx] for idx in [0..a.length-1])
# element-wise multiplication of two arrays
window.array_multiply = (a, b) ->
    if Array.isArray(a)
        if Array.isArray(b)
            (a[idx]*b[idx] for idx in [0..a.length-1])
        else
            (a[idx]*b for idx in [0..a.length-1])
    else
        if Array.isArray(b)
            (a*b[idx] for idx in [0..b.length-1])
        else
            a*b
# element-wise division of two arrays
window.array_divide = (a,b) ->
    if Array.isArray(a)
        if Array.isArray(b)
            (a[idx]/b[idx] for idx in [0..a.length-1])
        else
            (a[idx]/b for idx in [0..a.length-1])
    else
        if Array.isArray(b)
            (a/b[idx] for idx in [0..b.length-1])
        else
            a/b

# rotate a 2D point around another point
window.rotate = (p, theta, about=[0,0]) ->
    a = Math.PI*theta/180
    cs = Math.cos a
    sn = Math.sin a
    x = p[0] - about[0]
    y = p[1] - about[1]
    p = [
        x*cs - y*sn + about[0]
        x*sn + y*cs + about[1]
    ]

# pad a string with a character
window.string_pad = (x,n,chr='0') ->
    x = chr+x while (''+x).length < n
    x
# capitalize a string
window.capitalize = (str) ->
    str.charAt(0).toUpperCase() + str.slice(1)
# scramble a string
window.string_scramble = (str) ->
    str = str.split('')
    array_randomize str
    str.join ''

# calculate the divisors of an integer
window.divisors = (n, only_small=false) ->
    div_small = [1]
    div_large = [n]
    n_root = Math.floor(Math.sqrt(n))
    
    for i in [2..n_root]
        if n % i == 0
            div_small.push i
            
            if not only_small
                i_complement = n/i
                if i_complement != i
                    div_large.push i_complement
    
    if only_small
        div_small
    else
        div_small.concat div_large.reverse()
# factor n into two integers that are as equal as possible
window.sqrtish = (n, require_divisors=true) ->
    #if require_divisors is true, the two return values must multiply together
    #to be n. otherwise, the product of the two values is >= n, and more weight
    #is given to producing roughly equal integers
    
    if require_divisors
        d1 = divisors(n, true)
        d2 = array_divide(n,d1)
        diff = (Math.abs(x) for x in array_subtract(d1,d2))
        diff_min = Math.min(diff...)
        i = find(diff,diff_min,1)
        [Math.min(d1[i],d2[i]), Math.max(d1[i],d2[i])]
    else
        rc = [1..Math.max(1,Math.floor(Math.sqrt(n)))]
        cr = (Math.max(1,Math.ceil(n/x)) for x in rc)
    
        score = (1/((1+rc[i]*cr[i]-n)*Math.pow(1+cr[i]-rc[i],3)) for i in [0..rc.length-1])
        iMax = 0
        iMax = i for i in [1..score.length-1] when score[i]>score[iMax]
        row = Math.min(rc[iMax], cr[iMax])
        col = Math.max(rc[iMax], cr[iMax])
        [row, col]
# choose get a random integer from a range
window.random_int = (mn, mx, rng=Math.random) ->
    Math.floor(rng() * (mx - mn + 1)) + mn
# is a number even?
window.is_even = (x) ->
    (x % 2) == 0
# is a number odd?
window.is_odd = (x) ->
    ((x-1) % 2) == 0

###
# follow a path into an object
windows.objPath = (obj,path...) ->
    x = obj
    for el in path
        if x?
            x = x[el]
        else
            break
    x

remove = (obj, keys) -> objc = copy(obj); delete(objc[key]) for key in keys; objc

mod = (x,n) -> r=x%n; if r<0 then r+n else r
around = (x) -> (Math.round(e) for e in x)
window.nearest = (x,ref) ->
    df = (Math.abs(x-r) for r in ref)
    dfMin = Math.min(df...)
    return ref[i] for i in [0..ref.length-1] when df[i]==dfMin

fixAngle = (a) ->
    a = mod(a,360)
    if a>180 then a-360 else a
aan = (str) -> if str.length==0 or find("aeiou",str[0]).length==0 then 'a' else 'an'
contains = (x,v) ->
    for e in x
        if equals(e,v) then return true
    false
unique = (x) -> u=[]; u.push(e) for e in x when not contains(u,e); u
wordCount = (str) -> str.split(' ').length
msPerT = (unit) ->
    switch unit
        when 'day'
            86400000
        when 'hour', 'hr', 'h'
            3600000
        when 'minute', 'min', 'm'
            60000
        when 'second', 'sec', 's'
            1000
        when 'millisecond', 'msec', 'ms'
            1
        when 'dayminus10minutes'
            85800000
        else
            throw 'Invalid unit'
window.convertTime = (t,unitFrom,unitTo) -> t*msPerT(unitFrom)/msPerT(unitTo)
window.time2str = (t,showms=false) ->
    hours = Math.floor(convertTime(t,'ms','hour'))
    t -= convertTime(hours,'hour','ms')

    minutes = Math.floor(convertTime(t,'ms','minute'))
    t -= convertTime(minutes,'minute','ms')

    seconds = Math.floor(convertTime(t,'ms','second'))
    t -= convertTime(seconds,'second','ms')

    strHours = if hours>0 then "#{zpad(hours,2)}:" else ''
    strMinutes = "#{zpad(minutes,2)}:"
    strSeconds = zpad(seconds,2)
    strMS = if showms then ".#{t}" else ''
    "#{strHours}#{strMinutes}#{strSeconds}#{strMS}"
dec2frac = (x, tolerance=0.000001) ->
    #adapted from http://jonisalonen.com/2012/converting-decimal-numbers-to-ratios/
    [n1, n2] = [1, 0]
    [d1, d2] = [0, 1]
    b = x

    loop
        a = Math.floor(b)

        [n1, n2] = [a*n1+n2, n1]
        [d1, d2] = [a*d1+d2, d1]

        b = 1/(b - a)

        break if Math.abs(x-n1/d1) <= x*tolerance

    [n1, d1]
###