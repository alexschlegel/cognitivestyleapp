#requires lib.coffee

# class for running experiments
window.Experiment = class Experiment
    #whether to do debug stuff
    debug: false
    #the Django CSRF token
    csrf: null
    #the subject id
    subject: null
    #the div containing the Raphael canvas
    container: null
    #the Raphael object
    paper = null
    #the background element
    background: null
    #random number seed
    seed: null
    
    #copy some basic Raphael canvas properties/functions
    width: -> @paper.width
    height: -> @paper.height
    clear: -> @paper.clear()
    
    _default_data_url: '/data/'
    
    constructor: (options=null) ->
        #merge the specified options with the defaults
        options = merge_object {
            debug: false
            csrf: null
            data_url: @_default_data_url
            subject: null
            container: 'experiment'
            background: null
            images: []
            loadimages: false
            fixation: ["Circle", [{color:"red", r:5}]]
            seed: null
        }, (options ? {})
        
        #set some parameters
        @debug = options.debug
        @csrf = options.csrf
        @subject = options.subject ? @csrf
        
        #get the container reference
        if get_class(options.container)=='String'
            @container = $("\##{options.container}")
        else
            @container = options.container
        
        #create the canvas
        @paper = Raphael @container.attr('id')
        
        #make sure the container has focus and has tabindex 0 (for key events)
        @container.attr "tabindex", 0
        @container.focus()
        
        #sub objects
        @time = @Time()
        @color = @Color()
        @parameter = @Parameter()
        @data = @Data
            url: options.data_url
        @input = @Input()
        @do = @Do()
        @show = @Show()
        @trial = @Trial()
        
        #set the random seed
        @seed ?= @time.now()
        if @seed!=false then Math.seedrandom(@seed)
        
        #add the background
        if options.background?
            @background = @show.Rectangle
                color: options.background
                width: @width()
                height: @height()
        
        #warn about leaving
        $(window).on 'beforeunload', (e) ->
            e.returnValue = 'This will exit the experiment. Are you sure?'
    
    showObject: (obj) =>
        console.log obj
        $(document.body).append "<div style='position:absolute;left:0;top:0'>#{JSON.stringify(obj)}</div>"
    
    # base class for all experiment classes
    Class: class window.ExperimentClass
        #root Experiment object
        root: null
        
        #queue of functions to execute when the object is ready
        _ready: false
        _ready_queue = null
        
        constructor: (root, set_ready=true) ->
            @root = root
            
            if set_ready then @ready()
        
        #use to execute functions if the object is ready
        ready: (f=null) ->
            if f?
                if @_ready
                    f(@)
                else
                    @_ready_queue ?= []
                    @_ready_queue.push f
            else
                @_ready = true
                if @_ready_queue?
                    while @_ready_queue.length
                        @_ready_queue.shift()(@)
                    @_ready_queue = null
            @
    
    # class for dealing with time
    Time: -> new @ClassTime(@)
    ClassTime: class window.ExperimentClassTime extends ExperimentClass
        
        now: -> new Date().getTime()
        
        pause: (ms) ->
            tStart = @now()
            null while @now()<tStart+ms
    
    # class for dealing with colors
    Color: () -> new @ClassColor(@)
    ClassColor: class window.ExperimentClassColor extends ExperimentClass
        colors: null
        
        constructor: (root) ->
            super root
            
            @colors = {}
            
            @colors['default'] = ['red','blue','orange','limegreen','orangered','magenta']
            @colors['full'] = ['crimson','red','tomato','orangered','orange','gold','yellow','chartreuse','lime','limegreen','springgreen','aqua','turquoise','deepskyblue','blue','darkviolet','magenta','deeppink']
            @colors['difficulty'] = ['blue','limegreen','gold','orange','red']
        
        col2str: (color, a=1, brightness=1) ->
            color = Raphael.color(color)
            "rgba(#{color.r*brightness},#{color.g*brightness},#{color.b*brightness},#{a})"
        
        pick: (color_set='default', interpolate=false) ->
            if interpolate
                @blend @colors[color_set], Math.random()
            else
                pick_from @colors[color_set]
        
        blend: (color_set='default', f) ->
            num_colors = @colors[color_set].length
            
            idx_blend = Math.max(0,Math.min(num_colors-1,f*(num_colors-1)))
            idx_from = Math.floor(idx_blend)
            idx_to = Math.min(num_colors-1,idx_from + 1)
            
            f_blend = idx_blend - idx_from
            
            col_from = Raphael.color(@colors[colors_set][idx_from])
            col_to = Raphael.color(@colors[color_set][idx_to])
            
            r = (1-f_blend)*col_from.r + f_blend*col_to.r
            g = (1-f_blend)*col_from.g + f_blend*col_to.g
            b = (1-f_blend)*col_from.b + f_blend*col_to.b
            
            Raphael.color("rgb(#{r},#{g},#{b})")
        
        generator: (color_set='default') => new @ClassColorGenerator(@, color_set)
        ClassColorGenerator: class window.ExperimentClassColorGenerator
            _idx: -1
            _colors: null
            
            constructor: (parent, color_set) ->
                @_colors = parent.colors[color_set]
            
            next: () ->
                @_idx = (@_idx + 1) % @_colors.length
                @_colors[@_idx]
    
    Parameter: () -> new @ClassParameter(@)
    ClassParameter: class window.ExperimentClassParameter extends ExperimentClass
        Base: (values=null) -> new @ClassParameterBase(@root,values)
        ###
            values: either another object of the same class (to copy the
                parameters) or an object with explicitly specified parameter
                values
        ###
        ClassParameterBase: class window.ExperimentClassParameterBase extends ExperimentClass
            _keys: null
            
            constructor: (root, values) ->
                super root
                
                @_keys = []
                
                #explicitly specified parameter values
                if values instanceof @.constructor then values = values.toObject()
                if values? then for key,val of values
                    @_keys.push key
                    @[key] = val
                    
            
            _addParameter: (key, defaults, options) ->
                if not @[key]?
                    options = merge_object {
                        defaults: defaults
                        exclude: null
                        postprocess: null
                    }, (options ? {})
                    
                    #pick a parameter value
                    @_keys.push key
                    @[key] = @_pickValue options
                    
                    #postprocess
                    if options.postprocess? then @[key] = options.postprocess(@[name])
                    
            
            _pickValue: (options) ->
                #default values
                if options.defaults instanceof Function
                    values = options.defaults()
                else
                    values = options.defaults
                
                #exclude values
                if options.exclude?
                    if options.exclude instanceof Function
                        exclude = options.exclude()
                    else
                        exclude = options.exclude
                    
                    values = set_diff values, exclude
                
                #pick
                pick_from values
                
            copy: ->
                new (@constructor)(@root, @toObject())
            
            toObject: () ->
                obj = {}
                for key in @_keys
                    if @[key] instanceof ExperimentClassParameterBase
                        obj[key] = @[key].toObject()
                    else
                        obj[key] = @[key]
                obj
                
            toString: () ->
                obj2str @toObject()
        
        cycler: (values, options=null) => new @ClassParameterCycler(values, options)
        ClassParameterCycler: class window.ExperimentClassParameterCycler
            _idx: null
            _order: null
            _values: null
            
            _rng: null
            
            _restrict_iterations: 0
            
            constructor: (values, options) ->
                options ?= {}
                options.rng ?= Math.random
                
                @_rng = options.rng
                
                @_values = copy_object values
                @_order = [0..@_values.length-1]
                @_generate_order()
            
            next: (options=null) ->
                options ?= {}
                options.restrict ?= null
                
                idx = @_order[@_idx++]
                if @_idx==@_values.length then @_generate_order()
                next_value = @_values[idx]
                if options.restrict? and not (next_value in options.restrict)
                    @_restrict_iterations++
                    if @_restrict_iterations>@_order.length
                        throw 'cannot satisfy restriction'
                    
                    @next(options)
                else
                    @_restrict_iterations = 0
                    next_value
            
            _generate_order: () ->
                @_idx = 0
                array_randomize @_order, @_rng
        
        generate: (num, param_values, options={}, param_cyclers=null) ->
            options ?= {}
            options.order ?= Object.keys(param_values)
            options.aux_param_values ?= null
            options.randomize ?= true
            options.mutually_exclusive ?= null
            options.rng ?= Math.random
            
            #degenerate cases
            if num==0
                return []
            else if options.order.length==0
                return ({} for idx in [0..num-1])
            
            #used to randomly choose unbalanced parameter values
            if not param_cyclers?
                param_cyclers = {}
                for key,values of param_values
                    param_cyclers[key] = @cycler values,
                        rng: options.rng
            
            #get the number of parameters to generate per top level value
            top_key = options.order[0]
            top_values = param_values[top_key]
            num_values = top_values.length
            num_balanced = Math.floor num/num_values
            num_leftover = num - num_balanced*num_values
            num_per_value = fill_object top_values, num_balanced
            if num_leftover>0 then for leftover in [1..num_leftover]
                leftover_value = param_cyclers[top_key].next
                    restrict: top_values
                num_per_value[leftover_value]++
            sub_param_values = object_remove param_values, top_key
            sub_order = options.order[1..]
            
            #generate parameters for each top level value
            params_by_value = new Array(num_values)
            for idx in [0..num_values-1]
                current_value = param_values[top_key][idx]
                current_num = num_per_value[idx]
                
                #generate the excluded parameter values
                excluded_sub_param_values = @_excludeParameterValues sub_param_values, top_key, current_value, options.mutually_exclusive
                
                #generate the sub parameters
                params_by_value[idx] = @generate num_per_value[current_value], excluded_sub_param_values,
                    order: sub_order
                    randomize: options.randomize
                    mutually_exclusive: options.mutually_exclusive
                    rng: options.rng,
                    param_cyclers
                
                #now add in the top level parameter
                for p in params_by_value[idx]
                    p[top_key] = current_value
            
            #concatenate everything
            params = [].concat params_by_value...
            
            #add in the auxiliary parameters
            if options.aux_param_values? then for key,values of options.aux_param_values
                aux_param_cycler = @cycler values,
                    rng: options.rng
                
                for p in params
                    valid_values = @_getValidParameterValues key, values, p, options.mutually_exclusive
                    
                    p[key] = aux_param_cycler.next
                        restrict: valid_values
            
            #optionally randomize the parameter order
            if options.randomize then array_randomize params, options.rng
            
            params
        
        _excludeParameterValues: (param_values, exclude_key, exclude_value, mutually_exclusive) ->
            if mutually_exclusive?
                param_values = copy_object param_values, true
                
                for me_pair in mutually_exclusive
                    if exclude_key in me_pair
                        other_key = set_diff(me_pair, exclude_key)[0]
                        if other_key of param_values
                            param_values[other_key] = set_diff param_values[other_key], exclude_value
                        
            param_values
        _getValidParameterValues: (key, values, param, mutually_exclusive) ->
            if mutually_exclusive?
                values = copy_object values
                
                for me_pair in mutually_exclusive
                    if key in me_pair
                        other_key = set_diff(me_pair, key)[0]
                        if other_key of param
                            values = set_diff values, param[other_key]
            values
        
        countValues: (params, param_values, options) ->
            options ?= {}
            options.order ?= Object.keys(param_values)
            if options.order.length==0 then return params.length
            
            count = {_all: params.length}
            
            for key in options.order
                sub_order = (sub_key for sub_key in options.order when sub_key!=key)
                
                count[key] = {_each: []}
                for value in param_values[key]
                    sub_params = (p for p in params when p[key]==value)
                    count[key][value] = @countValues sub_params, param_values,
                        order: sub_order
                    
                    all_count = count[key][value]._all ? count[key][value]
                    count[key]._each.push all_count
            
            count
    
    # class for reading and writing data from the database
    Data: (options=null) => new @ClassData(@, options)
    ClassData: class window.ExperimentClassData extends ExperimentClass
        url: null
        timeout: null
        
        local: null
        
        store: null
        
        local_functions: null
        
        constructor: (root, options) ->
            options ?= {}
            options.url ?= null
            options.timeout ?= 10000
            options.local ?= (not options.url?)
            
            @_local_functions ?= {}
            
            @store = {}
            
            @url = options.url
            @timeout = options.timeout
            @local = options.local
            
            super root
            
            $.ajaxSetup {
                beforeSend: @_addCSRFToHeader
            }
        
        _csrfSafeMethod: (method) ->
            /^(GET|HEAD|OPTIONS|TRACE)$/.test(method)
        
        _addCSRFToHeader: (xhr, settings) =>
            if not @_csrfSafeMethod(settings.type) and not settings.crossDomain
                xhr.setRequestHeader "X-CSRFToken", @root.csrf
        
        ajax: (data, options=null) =>
            options ?= {}
            options.timeout ?= @timeout
            
            f_success = (result) => @["#{data.action}Success"](result, options)
            f_error = (jqXHR, status, err) => @["#{data.action}Error"](status, err, options)
            
            data.subject = @root.subject
            if not data.action? then throw 'no action specified'
            
            if @local
                result = {
                    success: true
                    action: data.action
                    status: data.action
                }
                
                switch data.action
                    when 'write'
                        result.key = data.key
                        result.value = JSON.parse data.value
                    when 'read'
                        result.key = data.key
                        result.value = @store[key]
                    when 'call'
                        if @_local_functions[data.f]?
                            args = JSON.parse data.args
                            result.output = @_local_functions[data.f](args...)
                        else
                            throw "#{data.f} is not a valid function"
                        end
                    else throw 'invalid action'
                
                window.setTimeout (=> f_success(result)), 0
            else
                $.ajax
                    type: 'POST'
                    url: @url
                    data: data
                    success: f_success
                    error: f_error
                    timeout: options.timeout
        
        write: (key, value, options=null) =>
            data = {
                action: 'write'
                key: key
                value: JSON.stringify value
            }
            @ajax data, options
        
        read: (key, options=null) =>
            data = {
                action: 'read'
                key: key
            }
            @ajax data, options
        
        call: (f, args=null, options=null) =>
            data = {
                action: 'call'
                f: f
                args: JSON.stringify force_array (args ? [])
            }
            @ajax data, options
        
        writeSuccess: (result, options) =>
            @store[result.key] = result.value
            if options.success? then options.success result
        
        readSuccess: (result, options) =>
            @store[result.key] = result.value
            if options.success? then options.success result
        
        writeError: (status, err, options) =>
            console.log 'write error!'
            if options.error? then options.error status, err
        
        readError: (status, err, options) =>
            console.log 'read error!'
            if options.error? then options.error status, err
        
        callSuccess: (result, options) =>
            if options.success? then options.success result
        
        callError: (status, err, options) =>
            console.log 'call error!'
            if options.error? then options.error status, err
    
    # class for getting user input
    Input: (options=null) => new @ClassInput(@, options)
    ClassInput: class window.ExperimentClassInput extends ExperimentClass
        _event_handlers: null
        
        _keys: null
        
        constructor: (root, options) ->
            super root
            
            options = merge_object {
                'key_yes': 'left'
                'key_no': 'right'
                'key_2choice0': 'left'
                'key_2choice1': 'right'
                'key_4choice0': 'left'
                'key_4choice1': 'up'
                'key_4choice2': 'right'
                'key_4choice3': 'down'
            }, (options ? {})
            
            @_keys = {}
            for key,val of options
                if key.startsWith 'key_'
                    @_keys[key.substring(4)] = val
            for n in [2, 4]
                group_name = "#{n}choice"
                @_keys[group_name] = (group_name+idx for idx in [0..n-1])
            
            @_event_handlers = {
                key_down: []
                mouse_down: []
            }
            
            #need to make sure the container has tabindex="0" and focus() has
            #been called in order for keydown to work
            @root.container.keydown( (evt) => @_handleKey(evt,'down') )
            @root.container.mousedown( (evt) => @_handleMouse(evt,'down') )
        
        addHandler: (type, options=null) ->
            #common options
            options ?= {}
            options.f ?= null
            options.expires ?= 0

            #type specific options
            switch type
                when 'key'
                    options.event ?= 'down'
                    options.button = force_array @key2code(options.button ? 'any')
                when 'mouse'
                    options.event ?= 'down'
                    options.button = force_array @mouse2code(options.button ? 'any')
                else throw "invalid handler type"
            
            #record number of event occurrences
            options.count = 0
            
            handler_type = "#{type}_#{options.event}"
            
            @_event_handlers[handler_type].push options

        key2code: (key) ->
            if Array.isArray key
                (@key2code k for k in key)
            else
                switch key
                    when 'any' then 'any'
                    when 'enter' then 13
                    when 'space' then 32
                    when 'left' then 37
                    when 'up' then 38
                    when 'right' then 39
                    when 'down' then 40
                    else
                        if get_class(key)=='String'
                            if key of @_keys
                                @key2code @_keys[key]
                            else
                                key.toUpperCase().charCodeAt(0)
                        else
                            key
        
        code2key: (key, valid_keys=null, valid_codes=null) ->
            if (not valid_codes?) and valid_keys?
                valid_codes = (@key2code(k) for k in valid_keys)
            
            if Array.isArray key
                (@code2key(k, valid_keys, valid_codes) for k in key)
            else
                if valid_keys?
                    idx_key = find valid_codes, key, 1
                    if idx_key.length
                        valid_keys[idx_key[0]]
                    else
                        null
                else
                    switch key
                        when 'any' then 'any'
                        when 13 then 'enter'
                        when 32 then 'space'
                        when 37 then 'left'
                        when 38 then 'up'
                        when 39 then 'right'
                        when 40 then 'down'
                        else String.fromCharCode(key).toUpperCase()
        
        key2synonym: (key) ->
            if Array.isArray key
                (@key2synonym(k) for k in key)
            else
                if get_class(key)=='String'
                    if key of @_keys
                        @key2synonym @_keys[key]
                    else
                        key
                else
                    @code2key key
        
        key2description: (key) ->
            key = force_array key
            if 'any' in key
                'any key'
            else
                key = @key2synonym key
                
                if key.length==1
                    key[0]
                else if key.length>1
                    key[0..key.length-2].join(', ') + ' or ' + key[key.length-1]
                else
                    'no key'
        
        mouse2code: (button) ->
            if Array.isArray button
                (@mouse2code for b in button)
            else
                switch button
                    when 'any' then 'any'
                    when 'left' then 1
                    when 'middle' then 2
                    when 'right' then 3
                    else throw "invalid button"
        
        code2mouse: (button) ->
            if Array.isArray button
                (@code2mouse for b in button)
            else
                switch button
                    when 'any' then 'any'
                    when 1 then 'left'
                    when 2 then 'middle'
                    when 3 then 'right'
                    else throw 'invalid button'
            
        _handleEvent: (evt, handler_type, f_check_handler) ->
            handlers = @_event_handlers[handler_type]
            
            #execute the handlers
            idx_remove = []
            for handler,idx in handlers
                if f_check_handler handler
                    handler.f evt
                    handler.count++
                    if handler.expires!=0 and handler.count>=handler.expires
                        idx_remove.push idx
            
            #remove expired handlers
            handlers.splice(idx,1) for idx in idx_remove
        
        _handleKey: (evt, event_type) ->
            handler_type = "key_#{event_type}"
            f_check_handler = (h) ->
                ('any' in h.button) or (evt.which in h.button)
            @_handleEvent(evt,handler_type,f_check_handler)

        _handleMouse: (evt, event_type) ->
            handler_type = "mouse_#{event_type}"
            f_check_handler = (h) ->
                ('any' in h.button) or (h.button in evt.which)
            @_handleEvent(evt,handler_type,f_check_handler)
    
    # class for doing things
    Do: => new @ClassDo(@)
    ClassDo: class window.ExperimentClassDo extends ExperimentClass
        # do a thing
        Action: (f) => new @ClassDoAction(@root, f)
        ###
            f: a function that takes no inputs
            options: a struct of options
        ###
        ClassDoAction: class window.ExperimentClassDoAction extends ExperimentClass
            f: null
            fire_time: null
            
            _callback_queue: null
            
            constructor: (root, f) ->
                super root
                @f = f
            
            fire: () =>
                @fire_time = @root.time.now()
                y = @f()
                @callback()
                y
            
            callback: (f=null) =>
                if f?
                #add a function to the callback queue
                    @_callback_queue ?= []
                    @_callback_queue.push f
                else if @_callback_queue?
                #execute the callbacks
                    for idx in [0..@_callback_queue.length-1]
                        f = @_callback_queue[idx]
                        
                        if f.fire instanceof Function
                            f.fire()
                        else
                            f()
                    @_callback_queue = null
                @
        
        # administer a questionnaire
        Questionnaire: (key, q) => new @ClassDoQuestionnaire(@root, key, q)
        ###
            key: the questionnaire key
            q:  the questionnaire definition. an array of objects specifying the
                questionnaire sequence. each object in the array has a 'key' and
                a 'value' element. valid keys are:
                    title: the questionnaire title
                    instruction: the instruction prompt
                    scale: an array of descriptions for Likert scale items
                    item: a questionnaire item prompt
                specifying any of these overwrite their previous values
            options:
                callback: a function to call once the questionnaire is
                            completed. takes the array of responses as input.
        ###
        ClassDoQuestionnaire: class window.ExperimentClassDoQuestionnaire extends ExperimentClassDoAction
            _key: null
            _q: null
            
            _idx: null
            
            result: null
            
            constructor: (root, key, q, options) ->
                f = @_do
                
                @_key = key
                @_q = q
                @result = {t: {}}
                
                super root, f
            
            callback: (f=null) =>
                if f?
                    super () => f(@result)
                else
                    super()
            
            fire: () =>
                @fire_time = @root.time.now()
                @f()
            
            _do: () =>
                @_startQuestionnaire()
            
            _doStep: (idx=null, do_items=true, stop_at=null) =>
                @_idx = Math.max(0,idx ? @_idx+1)
                
                if @_idx >= @_q.length
                    @_endQuestionnaire()
                    return
                    
                key = @_q[@_idx].key
                value = @_q[@_idx].value
                do_next = true
                switch key
                    when 'title', 'instruction'
                        @_element(key).html value
                    when 'scale'
                        el = @_element('response')
                        el.text ''
                        for response, index in value
                            input_value = index+1
                            el.append "<input type='radio' name='response' value='#{input_value}'>#{input_value} (#{response})<br>"
                            el.find("input[name=response][value=#{input_value}]").on 'click', ((v) => =>
                                @_recordResponse(v)
                                )(input_value)
                    when 'choice'
                        el = @_element('response')
                        el.text ''
                        for response, index in value
                            input_value = index+1
                            el.append "<input type='radio' name='response' value='#{input_value}'>#{response}<br>"
                            el.find("input[name=response][value=#{input_value}]").on 'click', ((v) => =>
                                @_recordResponse(v)
                                )(input_value)
                    when 'item'
                        if do_items
                            do_next = false
                            
                            n = @_getItemNumber()
                            c = @_getItemCount()
                            
                            @_error()
                            @_element('back').toggle(n!=1)
                            
                            if @_idx+1 >= @_q.length
                                @_element('submit').prop 'value', 'Submit Questionnaire'
                            else
                                @_element('submit').prop 'value', 'Next'
                            
                            @_element('prompt').html "#{n} of #{c}: #{value}"
                            
                            @_setResponse()
                    else throw 'invalid key'
                
                if do_next and (!stop_at? or @_idx<stop_at) then @_doStep(null, do_items, stop_at)
            
            _startQuestionnaire: () =>
                @result.t.start = @root.time.now()
                
                #initialize the responses
                c = @_getItemCount()
                @result.response = Array(c)
                @result.t.response = Array(c)
                
                #initialize the form
                body = $('body')
                body.append "<div class='questionnaire' id='#{@_htmlID()}'>
                                <h1 id='#{@_htmlID('title')}'></h1>
                                <div class='instruction' id='#{@_htmlID('instruction')}'></div>
                                <div class='item' id='#{@_htmlID('item')}'>
                                    <div class='prompt' id='#{@_htmlID('prompt')}'></div>
                                    <div class='response' id='#{@_htmlID('response')}'></div>
                                </div>
                                <div class='footer' id='#{@_htmlID('footer')}'>
                                    <div class='error' id='#{@_htmlID('error')}'></div>
                                    <input type='button' value='Back' id='#{@_htmlID('back')}'>
                                    <input type='button' value='Next' id='#{@_htmlID('submit')}'>
                                </div>
                            </div>"
                
                #set the button actions
                @_element('submit').on 'click', =>
                    response = @_getResponse()
                    
                    if response?
                        @_recordResponse(response)
                        @_doStep @_idx+1
                    else
                        @_error 'null_response'
                @_element('back').on 'click', =>
                    @_goBack()
                
                #execute the first step
                @_doStep(0)
            
            _endQuestionnaire: () =>
                @result.t.end = @root.time.now()
                @_element().remove()
                @callback()
            
            _getItemCount: () =>
                c = 0
                c++ for obj in @_q when obj.key=='item'
                c
            _getItemNumber: (idx=null) =>
                idx ?= @_idx
                idx_item = @_getNextItem(idx-1)
                
                n = 0
                n++ for obj in @_q[0..idx_item] when obj.key=='item'
                n
            _getPreviousItem: (idx=null) =>
                idx ?= @_idx
                idx_prev = null
                for idx_prev in [idx-1..0]
                    if @_q[idx_prev].key == 'item'
                        break
                idx_prev
            _getNextItem: (idx=null) =>
                idx ?= @_idx
                idx_next = null
                for idx_next in [idx+1..@_q.length-1]
                    if @_q[idx_next].key == 'item'
                        break
                idx_next
            
            _htmlID: (el='questionnaire') =>
                switch el
                    when 'questionnaire' then "#{el}_#{@_key}"
                    else "#{@_htmlID()}_#{el}"
            _element: (el='questionnaire') =>
                $("##{@_htmlID(el)}")
            
            _error: (error_type) =>
                el = @_element('error')
                el.text switch error_type
                    when 'null_response' then 'You must choose a response.'
                    else ''
            _getResponse: () =>
                response = @_element('response').find('input[name=response]:checked').val()
                if response? then response = Number(response)
            _setResponse: () =>
                idx = @_getItemNumber()-1
                response = @result.response[idx] ? (if @root.debug then 1 else null)
                @_element('response').find('input[name=response]').val([response])
            _recordResponse: (response) =>
                idx = @_getItemNumber()-1
                @result.t.response[idx] = @root.time.now()
                @result.response[idx] = response
            
            _goBack: () =>
                idx_pre = @_getPreviousItem()
                @_doStep 0, false, idx_pre
                @_doStep idx_pre
                
        
        # do a sequence of things
        Sequence: (f, next=null, options=null) => new @ClassDoSequence(@root, f, next, options)
        ###
            f: an array specifying the function or action to execute at each
                step
            next: an array specifying, for each element of f above:
                time: time to move on to the next step
                key: a key that must be down to move on
                f: a function that takes the sequence and step start times and
                    returns true to move on
                ['key'/'mouse', options]: specify input event that must occur
                    options:
                        event: ('down') the event type
                        button: ('any') the button that must fire the event
                        f: (<none>) a function that takes the event object as
                            input and is called when the event occurs
                ['event', f] specify a function that takes as input a function
                    that executes the next step, and registers an event that
                    will call that function when desired
                ['lazy', f] specify a function that will be called after the
                    step is executed, take this object and the current step
                    index as inputs, and return one of the above
                'callback': specify this if the function takes a function as an
                    input (the next step in the sequence) and executes that
                    function as a callback once ready
            options:
                time_format: the time format ('step', 'sequence', or 'absolute')
        ###
        ClassDoSequence: class window.ExperimentClassDoSequence extends ExperimentClass
            start_time: null
            step_time: null
            
            time_format: null
            
            _actions: null
            _next: null
            
            _check_next: null
            _check_next_f: null
            
            _callback_queue: null
            
            constructor: (root, f, next, options) ->
                super root
                
                options ?= {}
                @time_format = options.time_format ? 'step'
                
                num_step = f.length
                
                if not next?
                    next = (null for [0..num_step-1])
                @_next = next
                
                @_actions = Array(num_step-1)
                for idx in [0..num_step-1]
                    f_step = f[idx]
                    f_callback = ((i) => => @_processNext(i))(idx)
                    
                    if next[idx]=='callback'
                        if f_step instanceof @root.do.ClassDoAction
                            f_step.f = ((fs, fc) => => fs(fc))(f_step.f, f_callback)
                            @_actions[idx] = f_step
                        else
                            f_step = ((fs, fc) => => fs(fc))(f_step, f_callback)
                            @_actions[idx] = @root.do.Action(f_step)
                    else
                        if f_step instanceof @root.do.ClassDoAction
                            @_actions[idx] = f_step.callback(f_callback)
                        else
                            @_actions[idx] = @root.do.Action(f_step).callback(f_callback)
            
            fire: () ->
                @start_time = @root.time.now()
                if @_actions.length
                    @_actions[0].fire()
                else
                    @callback
                @
            
            _getDelayTime: (time) ->
                next_time = switch @time_format
                    when "step" then @step_time + time
                    when "sequence" then @start_time + time
                    when "absolute" then time
                    else throw "invalid time format"

                Math.max(0, next_time - @root.time.now())
            
            _processNext: (idx, next=null) ->
                @step_time = @_actions[idx].fire_time
                
                if idx==@_actions.length - 1
                    f_next = @callback
                else
                    f_next = @_actions[idx+1].fire
                
                next ?= @_next[idx]
                if not next? or next=='callback'
                    f_next()
                else if not isNaN(parseFloat(next)) #number
                    window.setTimeout f_next, @_getDelayTime next
                else if get_class(next)=='String' #key name
                    @_processNext idx, ['key', {button: next}]
                else if next instanceof Function #function to check periodically
                    @_check_next = next
                    @_check_next_f = f_next
                    @_timer = window.setInterval @_checkNext, 1
                else if Array.isArray(next) and next.length>0
                    switch next[0]
                        when 'key', 'mouse' #input event
                            f_register_event = (f) =>
                                options = if next.length>=2 then next[1] else {}
                                options.event = options.event ? 'down'
                                options.button = options.button ? 'any'
                                options.expires = 1
                                
                                if options.f?
                                    f_user = options.f
                                    options.f = (evt) => f_user(evt); f();
                                else
                                    options.f = (evt) => f()
                                
                                @root.input.addHandler(next[0],options)
                            
                            @_processNext idx, ['event', f_register_event]
                        when 'event'
                            next[1](f_next)
                        when 'lazy'
                            @_processNext idx, next[1](@root, idx)
                        else throw 'invalid event'
                else throw 'invalid event'
            
            _checkNext: () =>
                if @_check_next @start_time, @step_time
                    window.clearInterval @_timer
                    @_check_next_f()
            
            callback: (f=null) =>
                if f?
                #add a function to the callback queue
                    @_callback_queue ?= []
                    @_callback_queue.push f
                else if @_callback_queue?
                #execute the callbacks
                    #get the callback input arguments
                    args = @_getCallbackArgs()
                    
                    for idx in [0..@_callback_queue.length-1]
                        f = @_callback_queue[idx]
                        
                        if f.fire instanceof Function
                            f.fire(args...)
                        else
                            f(args...)
                    @_callback_queue = null
                @
            _getCallbackArgs: () ->
                []
    
    # class for showing things
    Show: => new @ClassShow(@)
    ClassShow: class window.ExperimentClassShow extends ExperimentClass
        
        # base stimulus class
        Stimulus: (options=null) => new @ClassShowStimulus(@root, options)
        ClassShowStimulus: class window.ExperimentClassShowStimulus extends ExperimentClass
            #Raphael element goes here
            element: null
            
            #default attributes
            _defaults: null
            _option_variants: null
            
            #custom attributes
            _attr: null
            
            #keep track of whether element is visible or hidden
            _show_state: true
            
            #transform element
            _rotation: 0
            _scale: 1
            _translation: [0, 0]
            
            # position helper functions
            _H_STRINGS: ['width','x','cx','l','cl','lc','h']
            _V_STRINGS: ['height','y','cy','t','ct','tc','v']
            isH: (type) -> @_H_STRINGS.indexOf(type) isnt -1
            isV: (type) -> @_V_STRINGS.indexOf(type) isnt -1
            addc: (x, type) -> if type[0]=='c' then "c#{x}" else x
            type2wh: (type) -> if @isH(type) then 'width' else 'height'
            type2xy: (type) -> @addc( (if @isH(type) then 'x' else 'y') , type)
            type2lt: (type) -> @addc( (if @isH(type) then 'l' else 't') , type)
            type2hv: (type) -> if @isH(type) then 'h' else if @isV(type) then 'v' else 'other'
            x2lc: (x) -> x + @root.width()/2
            lc2x: (l) -> l - @root.width()/2
            y2tc: (y) -> y + @root.height()/2
            tc2y: (t) -> t - @root.height()/2
            x2l: (x, width=null) -> @x2lc(x) - (width ? @attr("width"))/2
            l2x: (l, width=null) -> @lc2x(l) + (width ? @attr("width"))/2
            y2t: (y, height=null) -> @y2tc(y) - (height ? @attr("height"))/2
            t2y: (t, height=null) -> @tc2y(t) + (height ? @attr("height"))/2
            xy2lt: (v, xy) -> if @isH(xy) then @x2l(v) else @y2t(v)
            lt2xy: (v, xy) -> if @isH(xy) then @l2x(v) else @t2y(v)
            xy2ltc: (v, xy) -> if @isH(xy) then @x2lc(v) else @y2tc(v)
            ltc2xy: (v, xy) -> if @isH(xy) then @lc2x(v) else @tc2y(v)
            
            constructor: (root, options, set_ready=true) ->
                super root, false
                
                @_defaults = {}
                @_option_variants = {}
                @_attr = {}
                
                options = @_prepareOptions options
                
                @element = @_createElement options
                
                @_initAttributes options
                
                @ready() if set_ready
            
            #prepare the options
            _prepareOptions: (options) ->
                options ?= {}
                
                @_addDefaults {
                    width: 100
                    height: 100
                    x: 0
                    y: 0
                    color: "black"
                    stroke: "none"
                }
                
                @_addOptionVariants ['x','l']
                @_addOptionVariants ['y','t']
                
                #do it this way so the explicit options show up last
                prepared_options = {}
                for key,val of @_defaults
                    variant_exists = false
                    if key of @_option_variants
                        for variant in @_option_variants[key]
                            if variant of options
                                variant_exists = true
                                break
                    
                    if not variant_exists then prepared_options[key] = val
                
                for key,val of options
                    prepared_options[key] = val
                
                prepared_options
            
            #subclasses should override this method to create the element
            _createElement: (options) ->
                throw 'not implemented'
            
            #initialize the element attributes, given input options
            _initAttributes: (options) ->
                for name, value of options
                    @attr(name, value) if value?
            
            #add elements to the default attributes array
            _addDefaults: (obj, override=false) ->
                @_defaults ?= {}
                if override
                    @_defaults = merge_object @_defaults, obj
                else
                    @_defaults = merge_object obj, @_defaults
            
            #add options that are variants of each other
            _addOptionVariants: (variants) ->
                for key in variants
                    other = set_diff variants, key
                    if @_option_variants[key]?
                        @_option_variants[key] = @_option_variants[key].concat other
                    else
                        @_option_variants[key] = other
            
            # extension of Raphael's attr function
            attr: (name, value) ->
                switch name
                    when "color"
                        ret = @element.attr "fill", value
                    when "width", "height"
                        if value?
                            #set the new element value
                            current_size = @element.attr(name)
                            @element.attr(name, value)
                            
                            #keep the element centered at the old position
                            xy = @type2xy(name)
                            @attr xy, @attr(xy) - (value - current_size)/2
                        else
                            ret = @element.attr name
                    when "x", "y"
                        lt = @type2lt(name)
                        if value?
                            @attr lt, @xy2lt(value, name)
                        else
                            ret = @lt2xy(@attr(lt), name)
                    when "l", "t"
                        xy = @type2xy(name)
                        
                        if value?
                            @element.attr(xy, value)
                        else
                            ret = @element.attr(xy)
                    when "cx", "cy"
                        wh = @type2wh(name)
                        
                        if value?
                            @element.attr name, @xy2lt(value, name) + @attr(wh)/2
                        else
                            ret = @lt2xy(@element.attr(name), name) - @attr(wh)/2
                    when "lc", "tc"
                        lt = name[0]
                        wh = @type2wh(name)
                        
                        if value?
                            @attr lt, value - @attr(wh)/2
                        else
                            ret = @attr(lt) + @attr(wh)/2
                    when "click", "mousedown", "mouseup", "mouseover", "mouseout"
                        if value?
                            @element[name](value)
                        else
                            ret = @element[name]
                    when "box"
                        w = @attr "width"
                        h = @attr "height"
                        ret = box = [w,h]
                        
                        if value?
                            if not Array.isArray(value) then value = [value, value]

                        r = array_divide(value, box)
                        if r[0] < r[1]
                            @attr "width", value[0]
                            @attr "height", h*r[0]
                        else
                            @attr "width", w*r[1]
                            @attr "height", value[1]
                    when "show"
                        if value?
                            @_show_state = value
                            if value then @element.show() else @element.hide()
                        else
                            ret = @_show_state
                    else
                        ret = @element.attr(name, value)
                
                if value? then @ else ret
            
            _setTransform: ->
                @element.transform "r#{@_rotation},s#{@_scale},t#{@_translation}"
            rotate: (a, xc=null, yc=null) ->
                x = @attr 'x'
                y = @attr 'y'
                
                xc = xc ? x
                yc = yc ? y
                
                xDiff = x - xc
                yDiff = y - yc
                
                r = Math.sqrt(Math.pow(xDiff,2) + Math.pow(yDiff,2))
                theta = Math.atan2(yDiff, xDiff)
                theta += a*Math.PI/180
                
                @attr "x", r*Math.cos(theta) + xc
                @attr "y", r*Math.sin(theta) + yc

                @_rotation = (@_rotation + a) % 360
                @_setTransform()
            scale: (s, xc=null, yc=null) ->
                x = @attr 'x'
                y = @attr 'y'
                
                xc = xc ? x
                yc = yc ? y
                
                xDiff = x - xc
                yDiff = y - yc
                
                r = Math.sqrt(Math.pow(xDiff,2) + Math.pow(yDiff,2))
                theta = Math.atan2(yDiff, xDiff)
                r *= s
                
                @attr "x", r*Math.cos(theta) + xc
                @attr "y", r*Math.sin(theta) + yc
                
                @_scale = s*@_scale
                @_setTransform()
            translate: (x=0, y=0) ->
                @_translation[0] += x
                @_translation[1] += y
                @_setTransform()
            
            remove: -> if @element? then @element.remove(); @element = null
            
            click: (f) -> @attr "click", f
            mousedown: (f) -> @attr "mousedown", f
            mouseup: (f) -> @attr "mouseup", f
            mouseover: (f) -> @attr "mouseover", f
            mouseout: (f) -> @attr "mouseout", f
            
            toBack: -> @element.toBack()
            toFront: -> @element.toFront()
            
            show: (state=null) -> @attr "show", state
            
            exists: () -> @element?
        
        #combine multiple stimuli into a single element
        CompoundStimulus: (elements, options=null) => new @ClassShowCompoundStimulus(@root, elements, options)
        ClassShowCompoundStimulus: class window.ExperimentClassShowCompoundStimulus extends ExperimentClassShowStimulus
            _default_element: 0
            
            constructor: (root, elements, options) ->
                options ?= {}
                options.elements = elements
                
                super root, options
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    width: null
                    height: null
                    x: null
                    y: null
                    color: null
                    stroke: null
                }
                
                options = super options
            
            _createElement: (options) ->
                elements = object_extract options, 'elements'
                copy_object (if elements instanceof @root.show.ClassShowCompoundStimulus then elements.element else elements)
            
            attr: (name, value) ->
                switch name
                    when "width", "height"
                        xy = @type2xy(name)

                        n = @element.length
                        if n==0
                            p = 0
                            sz = 0
                        else
                            szAll = (el.attr(name) for el in @element)
                            pAll = (el.attr(xy) for el in @element)
                            pMin = Math.min (pAll[i] - szAll[i]/2 for i in [0..n-1])...
                            pMax = Math.max (pAll[i] + szAll[i]/2 for i in [0..n-1])...
                            
                            p = (pMin + pMax)/2
                            sz = pMax - pMin
                        
                        if value?
                            fSize = value/sz
                            if n>0
                                @element[i].attr(name, fSize*szAll[i]) for i in [0..n-1]
                                @element[i].attr(xy, fSize*(pAll[i]-p)+p) for i in [0..n-1]
                        else
                            ret = sz
                    when "l", "t"
                        n = @element.length
                        
                        if n==0
                            ret = p = switch name
                                when "l"
                                    @root.width()/2
                                when "t"
                                    @root.height()/2
                                else
                                    throw 'wtf?'
                        else
                            ret = p = Math.min (el.attr(name) for el in @element)...
                        
                        if value?
                            pMove = value - p
                            if n>0
                                el.attr(name, el.attr(name)+pMove) for el in @element
                    when "cl", "ct"
                        ret = @attr "#{name[1]}c", value
                    when "box", "x", "y", "cx", "cy", "lc", "tc"
                        ret = super name, value
                    when "element_mousedown"
                        ffEvent = (elm) -> (e,x,y) -> value(elm,x,y)
                        el.attr("mousedown", ffEvent(el)) for el in @element
                    else
                        if value?
                            el.attr(name, value) for el in @element
                        else
                            ret = if @element.length>0 then @element[@_default_element].attr(name) else null
                
                if value? then @ else ret
            
            _setTransform: -> el._setTransform() for el in @element
            rotate: (a, xc=null, yc=null) ->
                xc = xc ? @attr 'x'
                yc = yc ? @attr 'y'
                
                @_rotation = (@_rotation + a) % 360
                el.rotate(a,xc,yc) for el in @element
            scale: (s, xc=null, yc=null) ->
                xc = xc ? @attr 'x'
                yc = yc ? @attr 'y'
                
                @_scale = s*@_scale
                el.scale(s,xc,yc) for el in @element
            translate: (x=0, y=0) ->
                el.translate(x,y) for el in @element

            add: (el) ->
                @element ?= []
                @element.push el
                if not @_show_state then el.show(false)
            remove: (el=null, remove_element=true) ->
                if el?
                    idx = @getElementIndex(el)
                    
                    if remove_element then @element[idx].remove()
                    @element.splice(idx,1)
                else
                    if remove_element then (el.remove() for el in @element)
                    @element = []
            
            getElement: (el) ->
                if el instanceof @root.show.ClassShowStimulus then el else @element[el]
            getElementIndex: (el) ->
                if el instanceof @root.show.ClassShowStimulus then find(@element,el)[0] else el
        
        #arrange stimuli in a grid
        StimulusGrid: (elements, options=null) => new @ClassShowStimulusGrid(@root, elements, options)
        ClassShowStimulusGrid: class window.ExperimentClassShowStimulusGrid extends ExperimentClassShowCompoundStimulus
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    x: 0
                    y: 0
                    padding: 8
                    precise_grid: true
                }
                
                super options
            
            _initAttributes: (options) ->
                @_attr.padding = object_extract options, 'padding'
                @_attr.precise_grid = object_extract options, 'precise_grid'
                @_attr.rows = object_extract options, 'rows'
                @_attr.cols = object_extract options, 'cols'
                @_attr.x = object_extract options, 'x'
                @_attr.y = object_extract options, 'y'
                
                if not @_attr.rows?
                    if not @_attr.cols?
                        [@_attr.rows, @_attr.cols] = sqrtish @element.length, @_attr.precise_grid
                    else
                        @_attr.rows = Math.ceil @element.length/@_attr.cols
                else if not @_attr.cols?
                    @_attr.cols = Math.ceil @element.length/@_attr.rows
                
                @_updateElementPositions()
                
                super options
            
            #get the height of each row
            _getRowHeight: () ->
                rows = @attr 'rows'
                cols = @attr 'cols'
                
                row_height = new Array(rows)
                for r in [0..rows-1]
                    row_height[r] = 0
                    for c in [0..cols-1]
                        idx = cols*r + c
                        if idx>=@element.length then break
                        el_height = @element[idx].attr 'height'
                        row_height[r] = el_height if el_height > row_height[r]
                row_height
            #get the width of each column
            _getColWidth: () ->
                rows = @attr 'rows'
                cols = @attr 'cols'
                
                col_width = new Array(cols)
                for c in [0..cols-1]
                    col_width[c] = 0
                    for r in [0..rows-1]
                        idx = cols*r + c
                        if idx>=@element.length then break
                        el_width = @element[idx].attr 'width'
                        col_width[c] = el_width if el_width > col_width[c]
                col_width
            
            #update the grid positions
            _updateElementPositions: () ->
                @attr 'x', @attr('x')
                @attr 'y', @attr('y')
            
            attr: (name, value) ->
                switch name
                    when 'width', 'height'
                        if value?
                            #current size
                            current_size = @attr name
                            
                            #total padding
                            num_cells = switch name
                                when 'width' then @attr 'cols'
                                when 'height' then @attr 'rows'
                            pad = (num_cells-1)*@attr('padding')
                            
                            #get the resizing ratio
                            old_element_size = current_size - pad
                            new_element_size = value - pad
                            resize_ratio = new_element_size / old_element_size
                            
                            #resize the elements
                            for el in @element
                                el.attr name, resize_ratio*el.attr(name)
                            
                            @_updateElementPositions()
                        else
                            #get the current total element sizes
                            cell_sizes = switch name
                                when 'width' then @_getColWidth()
                                when 'height' then @_getRowHeight()
                            ret = array_sum cell_sizes
                            
                            #add the total padding
                            num_cells = switch name
                                when 'width' then @attr 'cols'
                                when 'height' then @attr 'rows'
                            ret += (num_cells-1)*@attr('padding')
                    when 'padding', 'rows', 'cols'
                        if value?
                            @_attr[name] = value
                            @_updateElementPositions()
                        else
                            ret = @_attr[name]
                    when 'x'
                        if value?
                            @_attr['x'] = value
                            
                            rows = @attr 'rows'
                            cols = @attr 'cols'
                            padding = @attr 'padding'
                            
                            col_width = @_getColWidth()
                            
                            value -= @attr('width')/2
                            for c in [0..cols-1]
                                value += col_width[c]/2
                                for r in [0..rows-1]
                                    idx = cols*r + c
                                    if idx>=@element.length then break
                                    @element[idx].attr name, value
                                value += col_width[c]/2 + padding
                        else
                            ret = @_attr[name]
                    when 'y'
                        if value?
                            @_attr['y'] = value
                            
                            rows = @attr 'rows'
                            cols = @attr 'cols'
                            padding = @attr 'padding'
                            
                            row_height = @_getRowHeight()
                            
                            value -= @attr('height')/2
                            for r in [0..rows-1]
                                value += row_height[r]/2
                                for c in [0..cols-1]
                                    idx = cols*r + c
                                    if idx>=@element.length then break
                                    @element[idx].attr name, value
                                value += row_height[r]/2 + padding
                        else
                            ret = @_attr[name]
                    else
                        ret = super name, value
                
                if value? then @ else ret
            
            add: (el) ->
                super el
                @_updateElementPositions()
            remove: (el, remove_element=true) ->
                super el, remove_element
                if @element.length then @_updateElementPositions()
        
        #arrange stimuli around a ring
        StimulusRing: (elements, options=null) => new @ClassShowStimulusRing(@root, elements, options)
        ###
           options:
                r: the ring radius. either a pixel value or one of the following:
                    'tight': the maximum element dimension
                    'loose': the maximum element diagonal dimension
        ###
        ClassShowStimulusRing: class window.ExperimentClassShowStimulusRing extends ExperimentClassShowCompoundStimulus
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    r: 'loose'
                    phase: 0
                }
                
                super options
            
            _initAttributes: (options) ->
                @_attr.r = 0
                @_attr.phase = 0
                
                super options
            
            attr: (name, value) ->
                switch name
                    when 'width', 'height'
                        if value?
                            @attr 'r', value/2
                        else
                            ret = super name
                    when 'r'
                        if value?
                            @_attr.r = switch value
                                when 'tight'
                                    el_size = (Math.max( el.attr('width'), el.attr('height') ) for el in @element)
                                    Math.max el_size...
                                when 'loose'
                                    el_size = (Math.sqrt( el.attr('width')**2 + el.attr('height')**2 ) for el in @element)
                                    Math.max el_size...
                                else
                                    value
                            
                            @_updateElementPositions()
                        else
                            ret = @_attr[name]
                    when 'phase'
                        if value?
                            @_attr.phase = value
                            
                            @_updateElementPositions()
                        else
                            ret = @_attr[name]
                    else
                        ret = super name, value
                
                if value? then @ else ret
            
            add: (el) ->
                super el
                @_updateElementPositions()
            remove: (el, remove_element=true) ->
                super el, remove_element
                @_updateElementPositions()
            
            _updateElementPositions: () ->
                if @element.length
                    x = @attr 'x'
                    y = @attr 'y'
                    
                    num_elements = @element.length
                    angle_step = 2*Math.PI / num_elements
                    for idx in [0..num_elements-1]
                        el_phase = Math.PI + @_attr.phase + idx*angle_step
                        
                        x_offset = @_attr.r * Math.cos(el_phase)
                        y_offset = @_attr.r * Math.sin(el_phase)
                        
                        @element[idx].attr 'x', x+x_offset
                        @element[idx].attr 'y', y+y_offset
            
        
        Rectangle: (options=null) => new @ClassShowRectangle(@root, options)
        ClassShowRectangle: class window.ExperimentClassShowRectangle extends ExperimentClassShowStimulus
            _createElement: (options) ->
                @root.paper.rect 0, 0, 0, 0
        
        Square: (options=null) => new @ClassShowSquare(@root, options)
        ClassShowSquare: class window.ExperimentClassShowSquare extends ExperimentClassShowRectangle
            _prepareOptions: (options) ->
                options = super options
                
                options.length ?= options.width ? options.height
                options.width = options.height = null
                
                options
            
            attr: (name, value) ->
                switch name
                    when "length", "width", "height"
                        if value?
                            super "width", value
                            super "height", value
                        else
                            ret = super "width"
                    else
                        ret = super name, value
                
                if value? then @ else ret
        
        Circle: (options=null) => new @ClassShowCircle(@root, options)
        ClassShowCircle: class window.ExperimentClassShowCircle extends ExperimentClassShowStimulus
            _prepareOptions: (options) ->
                @_addDefaults {
                    width: null
                    height: null
                    r: null
                }
                
                options = super options
                
                if options.width? or options.height?
                    options.r ?= (options.width ? options.height) / 2
                else
                    options.r ?= 50
                options.width = options.height = null
                
                options
            
            _createElement: (options) ->
                @root.paper.circle 0, 0, 0
            
            attr: (name, value) ->
                switch name
                    when "width", "height"
                        if value?
                            super "r", value/2
                        else
                            ret = 2*super "r"
                    when "l", "t"
                        xy = "c#{@type2xy(name)}"
                        wh = @type2wh(name)
                        
                        if value?
                            @element.attr(xy, value + @attr(wh)/2)
                        else
                            ret = @element.attr(xy) - @attr(wh)/2
                    else
                        ret = super name, value
                
                if value? then @ else ret
        
        Text: (text, options=null) => new @ClassShowText(@root, text, options)
        ClassShowText: class window.ExperimentClassShowText extends ExperimentClassShowStimulus
            _text: null
            
            _presets: {
                'instruction': {
                    'font-size': 24
                }
                'data': {
                    'font-family': 'monospace'
                    'font-size': 18
                }
            }
            
            constructor: (root, text, options) ->
                @_text = text
                
                super root, options
            
            _prepareOptions: (options) ->
                options = merge_object {
                    'preset': null
                }, (options ? {})
                
                if options.preset? then @_addDefaults @_presets[options.preset]
                
                @_addDefaults {
                    width: null
                    height: null
                    "font-family": "Arial"
                    "font-size": 14
                    "text-anchor": "middle"
                }
                
                options = super options
                
                if options.width? or options.height?
                    options['font-size'] = null
                
                options
            
            _createElement: (options) ->
                @root.paper.text 0, 0, @_text
            
            _initAttributes: (options) ->
                @_attr.x = 0
                @_attr.y = 0
                
                super options
            
            attr: (name, value) ->
                switch name
                    when "l"
                        if value?
                            @_attr.x = @l2x value
                            
                            offset = switch @attr('text-anchor')
                                when 'middle'
                                    @attr('width')/2
                                else
                                    0
                            
                            super name, value + offset
                        else
                            ret = @x2l @_attr.x
                    when "t"
                        if value?
                            @_attr.y = @t2y value
                            
                            half_height = @attr('height')/2
                            t = Math.min(@root.height()-half_height, value+half_height)
                            
                            super name, t
                        else
                            ret = @y2t @_attr.y
                    when "width", "height"
                        if value?
                            sz = @attr name
                            f = value / sz
                            
                            old_font_size = @attr 'font-size'
                            new_font_size = f*old_font_size
                            
                            @attr "font-size", new_font_size
                        else
                            ret = @element.getBBox()[name]
                    when "font-size"
                        if value?
                            x = @attr 'x'
                            y = @attr 'y'
                            
                            super name, value
                            
                            @attr 'x', x
                            @attr 'y', y
                        else
                            ret = super name
                    when 'text-anchor'
                        if value?
                            super name, value
                            @attr 'l', @attr('l')
                        else
                            ret = super name, value
                    else
                        ret = super name, value
                
                if value? then @ else ret
        
        #paths are specified as arrays of arrays, where each inner array
        #specifies one operation. coordinates are normalized to [0,1]. see
        #ClassShowX's constructor method for an example.
        Path: (path, options=null) => new @ClassShowPath(@root, path, options)
        ClassShowPath: class window.ExperimentClassShowPath extends ExperimentClassShowStimulus
            _path: null
            _param: null
            
            constructor: (root, path, options) ->
                @_path = path
                
                super root, options
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    stroke: 'black'
                    'stroke-width': 0
                }
                
                options = super options
            
            _createElement: (options) ->
                @root.paper.path ""
            
            _initAttributes: (options) ->
                @_attr.path = @_path
                @_attr.width = 0
                @_attr.height = 0
                @_attr.l = 0
                @_attr.t = 0
                @_attr.orientation = 0
                
                super options
            
            _bottomRightCorner: ->
                p = [@_attr.width/2, @_attr.height/2]
                rotate p, @_attr.orientation
            _topRightCorner: ->
                p = [@_attr.width/2, -@_attr.height/2]
                rotate p, @_attr.orientation
            _maxExtent: (idx) ->
                br = Math.abs @_bottomRightCorner()[idx]
                tr = Math.abs @_topRightCorner()[idx]
                2*Math.max(br, tr)
            
            rotatedWidth: -> @_maxExtent(0)
            rotatedHeight: -> @_maxExtent(1)
            
            attr: (name, value) ->
                switch name
                    when "path", "width", "height", "l", "t", "orientation"
                        if value?
                            attr = {}
                            attr[name] = value

                            if name=='width'
                              attr.l = @_attr.l + (@_attr.width-value)/2
                            else if name=='height'
                              attr.t = @_attr.t + (@_attr.height-value)/2

                            @_constructPath(attr)
                        else
                          ret = @_attr[name]
                    else
                        ret = super name, value
                
                if value? then @ else ret
            
            rotate: (a, xc=null, yc=null) ->
                if xc? or yc?
                    x = @attr "x"
                    y = @attr "y"
                    
                    xc = xc ? x
                    yc = yc ? y
                    
                    x_diff = x - xc
                    y_diff = y - yc
                    
                    r = Math.sqrt(Math.pow(x_diff,2) + Math.pow(y_diff,2))
                    theta = Math.atan2(y_diff, x_diff)
                    theta += a*Math.PI/180
                    
                    @attr "x", r*Math.cos(theta) + xc
                    @attr "y", r*Math.sin(theta) + yc
                
                @attr "orientation", @attr("orientation")+a

            _constructPath: (attr=null, set_path=true) ->
                attr ?= {}
                @_attr[key]=val for key,val of attr
                
                origin = @_transformPoint(0,0)
                path = "M" + origin

                for op in @_attr.path
                    path += op[0]
                    if op.length>1
                        switch op[0].toLowerCase()
                            when 'a'
                                offset=0
                                #radius
                                rx = op[++offset]*@_attr.width
                                ry = op[++offset]*@_attr.height
                                path += rx + ',' + ry + ','
                                #x-axis rotation
                                path += op[++offset] + ','
                                #large-arc and sweep flags
                                path += op[++offset] + ',' + op[++offset] + ','
                                #x, y end points
                                [x,y] = @_transformPoint(op[++offset],op[++offset])
                                path += x + ',' + y
                            else
                                for idx in [1..op.length-1] by 2
                                    p = @_transformPoint(op[idx],op[idx+1])
                                    path += p + ","
                
                if set_path then @element.attr "path", path else path
            _transformPoint: (x,y) ->
                #rotate
                [x,y] = rotate([x,y],@_attr.orientation,[0.5,0.5])
                #scale
                x *= @_attr.width
                y *= @_attr.height
                #translate
                x += @_attr.l
                y += @_attr.t
                [x,y]
        
        Shape: (name, options={}) => new @ClassShowShape(@root, name, options)
        ClassShowShape: class window.ExperimentClassShowShape extends ExperimentClassShowPath
            _name: null
            _presets: {
                triangle: [['M',0.5,0],['L',0,1],['L',1,1],['Z']]
                square: [['L',1,0],['L',1,1],['L',0,1],['Z']]
                pentagon: [['M',0.5,0],['L',1,0.382],['L',0.809,1],['L',0.191,1],['L',0,0.382],['Z']]
                diamond: [['M',0.5,0],['L',1,0.5],['L',0.5,1],['L',0,0.5],['Z']]
                circle: [['M',0.5,0],['A',0.5,0.5,0,1,1,0.4999,0],['Z']]
                star: [['M',0.5,0],['L',0.809,1],['L',0,0.382],['L',1,0.382],['L',0.191,1],['Z']]
                x: [['L',1,1],['M',0,1],['L',1,0]]
                plus: [['M',0.5,0],['L',0.5,1],['M',0,0.5],['L',1,0.5]]
                line: [['M',0.5,0],['L',0.5,1],['M',1,1]] #last move just to fill the space
                vline: [['M',0.5,0],['L',0.5,1],['M',1,1]]
                hline: [['M',0,0.5],['L',1,0.5],['M',1,1]]
            }
            _presets_with_stroke: ['x', 'plus', 'line']
            
            constructor: (root, name, options) ->
                @_name = name
                super root, [], options
                @setShape name
            
            _prepareOptions: (options) ->
                if @_name in @_presets_with_stroke
                    @_addDefaults {
                        'stroke': null
                        'stroke-width': 16
                    }
                
                options = super options
                
                options['stroke'] ?= options.color
                
                options
            
            setShape: (name) ->
                path = @_presets[@_name = name.toLowerCase()]
                @attr 'path', path
        
        X: (options=null) => new @ClassShowX(@root, options)
        ClassShowX: class window.ExperimentClassShowX extends ExperimentClassShowShape
            _prepareOptions: (options) ->
                @_addDefaults {
                    width: 16
                    height: 16
                    'stroke-width': 4
                }
                
                options = super options
            
            constructor: (root, options) ->
                super root, 'x', options
        
        Image: (src, options=null) => new @ClassShowImage(@root, src, options)
        ClassShowImage: class window.ExperimentClassShowImage extends ExperimentClassShowStimulus
            _src: null
            
            _default_width: null
            _default_height: null
            
            constructor: (root, src, options) ->
                @_src = src
                
                #get the default image size
                if not options.width? or not options.height?
                    im = new Image()
                    im.src = @_src
                    
                    if im.width == 0 #not yet loaded
                        im.onload = () => @constructor(root, @_src, options)
                        return
                    
                    @_default_width = im.width
                    @_default_height = im.height
                
                super root, options
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    width: @_default_width
                    height: @_default_height
                }
                
                options = super options
            
            _createElement: (options) ->
                @root.paper.image @_src, 0, 0, null, null

            attr: (name, value) ->
                switch name
                    when "color"
                        ret = null
                    else
                        ret = super name, value
                
                if value? then @ else ret
        
        Checkerboard: (options=null) => new @ClassShowCheckerboard(@root, options)
        ClassShowCheckerboard: class window.ExperimentClassShowCheckerboard extends ExperimentClassShowStimulusGrid
            
            constructor: (root, options) ->
                @root = root
                
                options ?= {}
                options.rows ?= (options.cols ? 8)
                options.cols ?= options.rows
                
                num = options.rows * options.cols
                elements = (@root.show.Rectangle() for [1..num])
                
                super root, elements, options
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    color1: 'black'
                    color2: 'white'
                    padding: 0
                    width: 100
                    height: 100
                }
                
                super options
            
            attr: (name, value) ->
                switch name
                    when "width"
                        if value?
                            rows = @attr 'rows'
                            cols = @attr 'cols'
                            pad = @attr 'padding'
                            
                            w = (value)/cols
                            w_pad = (value-cols*pad)/cols
                            x = @attr 'x'
                            for r in [0..rows-1]
                                for c in [0..cols-1]
                                    idx = r*cols + c
                                    el = @element[idx]
                                    el.attr 'width', w_pad
                                    el.attr 'x', x - (value-w)/2 + c*w
                        else
                            ret = super name, value
                    when "height"
                        if value?
                            rows = @attr 'rows'
                            cols = @attr 'cols'
                            pad = @attr 'padding'
                            
                            h = value/rows
                            h_pad = (value-rows*pad)/rows
                            y = @attr 'y'
                            for r in [0..rows-1]
                                for c in [0..cols-1]
                                    idx = r*cols + c
                                    el = @element[idx]
                                    el.attr 'height', h_pad
                                    el.attr 'y', y - (value-h)/2 + r*h
                        else
                            ret = super name, value
                    when "color1", "color2"
                        offsets = if name=='color1' then [0,1] else [1,0]
                        
                        if value?
                            rows = @attr 'rows'
                            cols = @attr 'cols'
                            
                            for r in [0..rows-1]
                                col_start = if is_even(r) then offsets[0] else offsets[1]
                                for c in [col_start..cols-1] by 2
                                    idx = r*cols + c
                                    @element[idx].attr 'color', value
                        else
                            if @element.length
                                @element[offsets[0]].attr 'color'
                            else
                                null
                    else
                        ret = super name, value
                
                if value? then @ else ret
                
            
        
        Choice: (elements, options=null) => new @ClassShowChoice(@root, elements, options)
        ###
            options:
                type: ('element') one of the following:
                    'element': user must click one of the elements
                    'key': user must press a key
                    'yesno': user must press a key to choose between 'yes' and
                        'no'
                    'multichoice': user must press a key to choose between one
                        of the elements (see the key mapping in the Input
                        object)
                group: one of the following:
                    'ring': arrange as a stimulus ring (default for multichoice)
                    'grid': arrange as a stimulus grid (default for others)
                group_options: options for the stimulus group
                prompt: (<depends on type>) the prompt text to show beneath the
                    choices, or false to not show a prompt
                prompt_suffix: (null) suffix to add to the end of default
                    prompts
                prompt_options: (<see below>) options for the prompt text
                key: ('any') for key response types, the valid key choices
                timeout: (<none>) number of milliseconds before the choice times
                    out
        ###
        ClassShowChoice: class window.ExperimentClassShowChoice extends ExperimentClassShowStimulusGrid
            choice: null
            timeout: null
            
            _t_start: 0
            
            _type: null
            _group: null
            _prompt: null
            
            _callback_queue: null
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    type: 'element'
                    group: null
                    group_options: {}
                    prompt: null
                    prompt_suffix: null
                    prompt_options: {'font-style':'italic'}
                    key: 'any'
                    timeout: null
                    cols: 1
                    padding: 18
                }
                
                options = super options
                
                #group type
                options.group ?= if options.type=='multichoice' then 'ring' else 'grid'
                
                #default prompt suffix
                if options.prompt_suffix?
                    options.prompt_suffix = " #{options.prompt_suffix}"
                else
                    options.prompt_suffix = ''
                
                #default prompts
                not options.prompt ?= switch options.type
                    when 'element' then "Choose one#{options.prompt_suffix}."
                    when 'key' then "Press #{@root.input.key2description(options.key)}#{options.prompt_suffix}."
                    when 'yesno'
                        key_yes = @root.input.key2synonym 'yes'
                        key_no = @root.input.key2synonym 'no'
                        "Yes (#{key_yes}) or No (#{key_no})#{options.prompt_suffix}"
                    when 'multichoice'
                        n = options.elements.length
                        keys = @root.input._keys["#{n}choice"]
                        "Press #{@root.input.key2description(keys)}#{options.prompt_suffix}."
                    when false
                        null
                    else throw 'invalid choice type'
                
                options
            
            _createElement: (options) ->
                #group the elements
                @_group = super options
                group_type = object_extract options, 'group'
                group_options = object_extract options, 'group_options'
                switch group_type
                    when 'grid'
                        @_group = @root.show.StimulusGrid @_group, group_options
                    when 'ring'
                        @_group = @root.show.StimulusRing @_group, group_options
                    else throw "#{group_type} is an invalid grouping type"
                
                elements = [@_group]
                
                #choice prompt
                prompt = object_extract options, 'prompt'
                prompt_options = object_extract options, 'prompt_options'
                if prompt
                    prompt_options = merge_object {
                        preset: 'instruction'
                    }, prompt_options
                    @_prompt = @root.show.Text prompt, prompt_options
                    elements.push @_prompt
                
                elements
            
            _initAttributes: (options) ->
                @_type = object_extract options, 'type'
                @timeout = object_extract options, 'timeout'
                
                super options
                
                #set up the choice event
                switch @_type
                    when 'element'
                        #set a mousedown event for each element
                        for idx in [0..@_group.length-1]
                            f_down = ((i) => (e,x,y) => @_choiceEvent(i))(idx)
                            @_group[idx].mousedown f_down
                    when 'key'
                        key_options = {
                            event: 'down'
                            button: options.key
                            expires: 1
                            f: (e) => @_choiceEvent(@root.input.code2key(e.which))
                        }
                        @root.input.addHandler('key',key_options)
                    when 'yesno'
                        keys = ['yes', 'no']
                        key_options = {
                            event: 'down'
                            button: keys
                            expires: 1
                            f: (e) => @_choiceEvent(@root.input.code2key(e.which, keys))
                        }
                        
                        @root.input.addHandler('key',key_options)
                    when 'multichoice'
                        keys = @root.input._keys["#{@_group.element.length}choice"]
                        key_options = {
                            event: 'down'
                            button: keys
                            expires: 1
                            f: (e) => @_choiceEvent(@root.input.code2key(e.which, keys))
                        }
                        
                        @root.input.addHandler('key',key_options)
                    when false
                        null
                    else throw 'invalid choice type'
                
                @_t_start = @root.time.now()
                if @timeout? then window.setTimeout (=> @_choiceEvent(null)), @timeout
            
            attr: (name, value) ->
                switch name
                    when 'y'
                        if value?
                            if @_prompt then value += (@_prompt.attr('height')+@attr('padding'))/2
                            super name, value
                        else
                            ret = super name, value
                    else
                        ret = super name, value
                
                if value? then @ else ret
            
            # add a function to execute when the choice is made. the function
            # takes this object and the choice info object as inputs
            callback: (f) ->
                if @choice?
                    f(@, @choice)
                else
                    @_callback_queue ?= []
                    @_callback_queue.push f
                @
            
            _processChoice: (choice) ->
                t_now = @root.time.now()
                
                switch @_type
                    when 'yesno'
                        choice = if choice=='yes' then true else false
                    when 'multichoice'
                        match = choice.match(/^\d+choice(\d+)$/)
                        if match
                            choice = Number(match[1])
                
                {
                    start: @_t_start
                    end: t_now
                    rt: t_now - @_t_start
                    choice: choice
                }
            _choiceEvent: (choice) ->
                if not @choice?
                    @choice = @_processChoice(choice)
                    
                    if @_callback_queue?
                        for f in @_callback_queue
                            f(@, @choice)
        
        Instruction: (text, options=null) => new @ClassShowInstruction(@root, text, options)
        ClassShowInstruction: class window.ExperimentClassShowInstruction extends ExperimentClassShowChoice
            constructor: (root, text, options) ->
                elements = [exp.show.Text text, {preset: 'instruction'}]
                
                super root, elements, options
                
                @callback (obj,choice) -> obj.remove()
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    type: 'key'
                }
                
                options = super options
                
                options.prompt ?= switch options.type
                    when 'key'
                        'Press a key.'
                    else null
                
                options
        
        Test: (elements, options=null) => new @ClassShowTest(@root, elements, options)
        ###
            options:
                target: the index of the correct choice / array of indices.
                    if this is unspecified, then each stimulus object should
                    have a boolean property named "correct" that specifies
                    whether the stimulus is a correct choice.
        ###
        ClassShowTest: class window.ExperimentClassShowTest extends ExperimentClassShowChoice
            target: null
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    target: null
                }
                
                options = super options
                
                @target = object_extract options, 'target'
                
                options
            
            _createElement: (options) ->
                element = super options
                
                if not @target?
                    @target = []
                    choices = element[0].element
                    for idx in [0..choices.length-1]
                        if choices[idx].correct then @target.push idx
                
                element
            
            _processChoice: (choice) ->
                result = super choice
                
                result.target = @target
                result.correct = result.choice? and (result.choice in force_array(@target))
                
                result
        
        # show a sequence of things
        Sequence: (stim, next, options=null) => new @ClassShowSequence(@root, stim, next, options)
        ###
            stim: an array of:
                [<name of show function>, <arg1 to show class>, ...]
                a Stimulus (hidden)
                a function/action that returns an array of the above
            next: see Sequence superclass, or
                ['choice', options] (create Show.Choice from current stimuli)
                ['test', options] (create Show.Test from current stimuli)
            options:
                cleanup: ('step') the type of stimulus cleanup to perform. one
                    of:
                    'step': cleanup stimuli at the start of the next step
                    'sequence': cleanup stimuli at the end of the sequence
                    'none': don't cleanup stimuli
                fixation: (false) true to show the fixation dot at each step
                (also see Sequence superclass)
        ###
        ClassShowSequence: class window.ExperimentClassShowSequence extends ExperimentClassDoSequence
            result: null
            
            _stim: null
            _step: null
            
            _cleanup: null
            _stim_step: null
            
            constructor: (root, stim, next, options) ->
                options = merge_object {
                    cleanup: 'step'
                    fixation: false
                }, options
                
                @_cleanup = options.cleanup
                
                num_step = stim.length
                
                #array to store stimuli for each step
                @_stim_step  = ([] for idx in [0..num_step-1])
                
                #result of each step
                @result = ({} for idx in [0..num_step-1])
                
                #construct the functions to show each stimulus
                @_stim = stim
                f_stim = ( ((i) => => @_showStim(i))(idx) for idx in [0..num_step-1] )
                
                #last step to clean up the sequence
                f_stim.push @_cleanupStimuli
                next.push null
                
                super root, f_stim, next, options
            
            _processNext: (idx, next=null) ->
                next ?= @_next[idx]
                
                if Array.isArray(next) and next.length>0 and (next[0]=='choice' or next[0]=='test')
                    options = if next.length>1 then next[1] else {}
                    
                    f_show = (f_next) =>
                        stim = @root.show[capitalize(next[0])](@_stim_step[idx], options)
                        stim.callback (obj,choice) =>
                            @_recordTime idx, 'choice', choice.end
                            @result[idx].choice = choice.choice
                            @result[idx].rt = @result[idx].t.choice - @result[idx].t.show
                            if obj instanceof @root.show.ClassShowTest
                                @result[idx].target = choice.target
                                @result[idx].correct = choice.correct
                            f_next()
                        @_recordStimulus idx, stim
                    
                    super idx, ['event', f_show]
                else
                    super idx, next
            
            _showStim: (idx, stim=null) ->
                if not stim?
                    @_step = idx
                    
                    stim = @_stim[idx]
                    
                    if idx>0 then @_cleanupStimuli(idx-1)
                    
                    @result[idx] = {
                        t: {}
                        t_rel: {}
                    }
                    @_recordTime idx, 'show'
                
                if not stim?
                    null
                else if not Array.isArray stim
                    @_showStim idx, [stim]
                else if stim.length>0 and get_class(stim[0])=='String'
                    @_recordStimulus idx, @root.show[stim[0]](stim[1..]...)
                else
                    for s in stim
                        if Array.isArray(s)
                            @_showStim idx, s
                        else if s instanceof @root.show.ClassShowStimulus
                            @_recordStimulus idx, s
                            s.show true
                        else if s instanceof @root.do.ClassDoAction
                            @_showStim idx, s.fire()
                        else if s instanceof Function
                            @_showStim idx, s()
                        else throw "invalid stimulus for step #{idx}"
            
            _recordStimulus: (idx, stim) ->
                @_stim_step[idx].push stim
            
            _recordTime: (idx, name, time=null) ->
                time ?= @root.time.now()
                @result[idx].t[name] = time
                @result[idx].t_rel[name] = time - @start_time
            
            _cleanupStimuli: (idx=null) =>
                if idx?
                    @_recordTime idx, 'remove'
                    
                    switch @_cleanup
                        when 'step'
                            stim.remove() for stim in @_stim_step[idx]
                        when 'sequence'
                            stim.show(false) for stim in @_stim_step[idx]
                        when 'none'
                            null
                        else throw 'invalid cleanup value'
                else
                    switch @_cleanup
                        when 'step'
                            idx = @_stim.length - 1
                            stim.remove() for stim in @_stim_step[idx]
                        when 'sequence'
                            for idx in [0..@_stim.length-1]
                                stim.remove() for stim in @_stim_step[idx]
                        when 'none'
                            null
                        else throw 'invalid cleanup value'
            
            _getCallbackArgs: () ->
                [@result]
    
    # class for running trials
    Trial: => new @ClassTrial(@)
    ClassTrial: class window.ExperimentClassTrial extends ExperimentClass
        # base trial class
        Base: (options=null) -> new @ClassTrialBase(@root, options)
        ClassTrialBase: class window.ExperimentClassTrialBase extends ExperimentClassShowSequence
            _feedback_time: 1000
            
            constructor: (root, options) ->
                @root = root
                
                options = merge_object {
                    target: null
                    feedback_time: null
                    test_group_options: null
                    test_prompt_options: null
                }, (options ? {})
                
                @_feedback_time = options.feedback_time if options.feedback_time?
                
                sequence_stim = force_array @_getSequenceStim(options)
                sequence_next = force_array @_getSequenceNext(sequence_stim, options)
                num_sequence = sequence_stim.length
                
                test_stim = force_array @_getTestStim(options)
                test_next = @_getTestNext test_stim, options
                idx_test = num_sequence
                
                feedback_stim = => @_getFeedbackStim(@result[idx_test], options)
                feedback_next = ['lazy', (obj, step) => @_getFeedbackNext(@result[idx_test], options)]
                
                stim = sequence_stim.concat [test_stim, feedback_stim]
                next = sequence_next.concat [test_next, feedback_next]
                
                super root, stim, next, options
            
            #get an array of trial sequence stim values
            _getSequenceStim: (options) =>
                [['Text', 'prompt']]
            
            #get the trial sequence next
            _getSequenceNext: (sequence_stim, options) =>
                (1000 for [1..sequence_stim.length])
            
            #get an array of test stimuli that the subject will choose from
            _getTestStim: (options) =>
                [['Text', 'test']]
            
            #get the test next value
            _getTestNext: (test_stim, options) =>
                n = test_stim.length
                target = options.target
                switch n
                    when 0 then throw 'unsupported number of test stimuli'
                    when 1
                        target ?= true
                        type = 'yesno'
                    else
                        target ?= 0
                        type = 'multichoice'
                
                ['test', {
                    target: target
                    type: type
                    group_options: object_extract options, 'test_group_options'
                    prompt_options: object_extract options, 'test_prompt_options'
                }]
            
            #get the feedback stimulus
            _getFeedbackStim: (result, options) =>
                text = if result.correct then 'Correct!' else 'Wrong!'
                color = if result.correct then 'limegreen' else 'red'
                @root.show.Text text,
                    preset: 'instruction'
                    color: color
                    show: false
            
            #get the feedback next value
            _getFeedbackNext: (result, options) =>
                @_feedback_time
            
            getResult: () =>
                @result
            
            _getCallbackArgs: () ->
                [@getResult()]
            