window.CognitiveStyle = class CognitiveStyle extends Experiment
    version: null
    
    _advance_key: 'space'
    
    _key_yes: 'F'
    _key_no: 'J'
    
    _instruct_num_trials: 16
    _instruct_text_options: {
        preset: 'instruction'
        "font-size": 24
        color: 'rgb(0,0,160)'
        show: false
    }
    
    _verbal_stimulus_font_size: 32
    _visual_stimulus_size: 75
    _row_padding: 12
    _col_padding: 32
    _test_ring_radius: 'tight'
    
    constructor: (options=null) ->
        options = merge_object {
            data_url: 'data/'
            version: 2
        }, (options ? {})
        
        #set the version
        @version = options.version
        if not @version in [1, 2] then throw 'invalid version'
        
        super options
    
    fetchCompletionCode: (result, callback) =>
        @data.call 'completioncode', [result],
            success: (result) => callback(result.output)
            error: (status, err) => callback(err)
    
    summaryStatistics: (result) =>
        stat = @_summaryStatisticsAll result
        
        for prompt_format in ['verbal', 'visual']
            [prompt_key, current_result] = @_filterResult result, 'prompt', prompt_format
            stat[prompt_key] = @_summaryStatisticsAll current_result
            
            for test_format in ['verbal', 'visual']
                [test_key, sub_result] = @_filterResult current_result, 'test', test_format
                stat[prompt_key][test_key] = @_summaryStatisticsAll sub_result
        
        for test_format in ['verbal', 'visual']
            [test_key, current_result] = @_filterResult result, 'test', test_format
            stat[test_key] = @_summaryStatisticsAll current_result
            
            for prompt_format in ['verbal', 'visual']
                [prompt_key, sub_result] = @_filterResult current_result, 'prompt', prompt_format
                stat[test_key][prompt_key] = @_summaryStatisticsAll sub_result
        
        stat
    _filterResult: (result, type, format) =>
        key = "#{type}_#{format}"
        result = (res for res in result when res.param["#{type}_format"]==format)
        [key, result]
    _summaryStatisticsAll: (result) =>
        {
            num_trials: result.length
            encoding_rt: array_mean(res.encoding_rt for res in result)
            verification_rt: array_mean(res.verification_rt for res in result)
            accuracy: array_mean((if res.correct then 1 else 0) for res in result)
        }
    
    ClassParameter: class window.CognitiveStyleClassParameter extends ExperimentClassParameter
        _colors: ['red', 'black']
        _formats: ['visual', 'verbal']
        _targets: null #set in constructor below
        _relations: ['left','right','above','below']
        _shapes: ['star', 'plus', 'square', 'circle', 'triangle']
        _catches: null #set in constructor below
        _negates: [false] #[true, false]
        
        _num_distractors: 3
        
        _reps: null #number of reps of the completely balanced parameter set
        _trials_per_block: 32
        
        _trial_param_values: null
        _trial_aux_param_values: null
        _trial_mutually_exclusive: null
        
        constructor: (root, set_ready=null) ->
            super root, set_ready
            
            switch @root.version
                when 1
                    @_catches = ['order', 'relation'] #['order', 'shape', 'negate', 'relation']
                    @_targets = [true, false]
                    @_reps = 4
                when 2
                    @_catches = []
                    for change_shape in [1, 2, false, false]
                        for change_order in [true, false]
                            if change_shape
                                change_relations = [true, false]
                            else
                                change_relations = [not change_order]
                            
                            for change_relation in change_relations
                                @_catches.push {
                                    shape: change_shape
                                    order: change_order
                                    relation: change_relation
                                }
                    
                    @_targets = [0..@_num_distractors]
                    @_reps = 2
            
            @_trial_param_values = {
                prompt_format: @_formats
                test_format: @_formats
                target: @_targets
                relation: @_relations
                negate: @_negates
            }
            @_trial_aux_param_values = {
                shape1: @_shapes
                shape2: @_shapes
                catch: @_catches
            }
            @_trial_mutually_exclusive = [['shape1', 'shape2']]
            
            if @root.version==2
                @_trial_aux_param_values['distractor_shape'] = @_shapes
                
                @_trial_mutually_exclusive.push ['distractor_shape', 'shape1']
                @_trial_mutually_exclusive.push ['distractor_shape', 'shape2']
                
                num_distractor = @_num_distractors
                for idx in [0..num_distractor-1]
                    @_trial_aux_param_values["d#{idx}_type"] = @_catches
                    
                    if idx<num_distractor-1 then for idx_exclude in [idx+1..num_distractor-1]
                        @_trial_mutually_exclusive.push ["d#{idx}_type", "d#{idx_exclude}_type"]
        
        getDefaultNumTrials: () =>
            num_per_param = (values.length for key,values of @_trial_param_values)
            @_reps * array_prod num_per_param
        
        getSequenceParam: (options=null) =>
            options ?= {}
            options.randomize ?= true
            
            sequence_param = @root.parameter.TrialSequence
                num_trials: options.num_trials
                seed: 101181
            
            if options.randomize? then array_randomize sequence_param.trial_param
            
            sequence_param
        
        Stimulus: (values=null) => new @ClassParameterStimulus(@root, values)
        ClassParameterStimulus: class window.CognitiveStyleClassParameterStimulus extends ExperimentClassParameterBase
            constructor: (root, values) ->
                super root, values
                
                @_addParameter 'shape1', @root.parameter._shapes
                @_addParameter 'shape2', @root.parameter._shapes,
                    exclude: @shape1
                @_addParameter 'relation', @root.parameter._relations
                @_addParameter 'negate', @root.parameter._negates
                
            switchRelation: () =>
                @relation = switch @relation
                    when 'left' then 'right'
                    when 'right' then 'left'
                    when 'above' then 'below'
                    when 'below' then 'above'
                @
            
            switchOrder: () =>
                [@shape1, @shape2] = [@shape2, @shape1]
                @
            
            switchNegate: () =>
                @negate = not @negate
                @
            
            switchShape: (shape_number=null, new_shape=null) =>
                if not new_shape?
                    new_shape = @_pickValue
                        defaults: @root.parameter._shapes
                        exclude: [@shape1, @shape2]
                
                shape_number ?= random_int 1, 2
                
                @["shape#{shape_number}"] = new_shape
                @
        
        Trial: (values=null) => new @ClassParameterTrial(@root, values)
        ClassParameterTrial: class window.CognitiveStyleClassParameterTrial extends ExperimentClassParameterBase
            constructor: (root, values) ->
                super root, values
                
                @_addParameter 'target', @root.parameter._targets
                @_addParameter 'stimulus_param', {},
                    postprocess: @root.parameter.Stimulus
                @_addParameter 'prompt_format', @root.parameter._formats
                @_addParameter 'test_format', @root.parameter._formats
                
                switch @root.version
                    when 1
                        @_addParameter 'catch', @root.parameter._catches
                    when 2
                        @_addParameter 'distractor_shape', @root.parameter._shapes,
                            exclude: [@stimulus_param.shape1, @stimulus_param.shape2]
                        
                        exclude = []
                        for idx in [0..@root.parameter._num_distractors-1]
                            name = "d#{idx}_type"
                            @_addParameter name, @root.parameter._catches,
                                exclude: exclude
                            exclude.push @[name]
                
                @prompt_param = @_getPromptParameter()
                @test_param = @_getTestParameter()
                
            _getPromptParameter: () =>
                @root.parameter.Stimulus @stimulus_param
            
            _getTestParameter: () =>
                switch @root.version
                    when 1
                        param = @root.parameter.Stimulus @stimulus_param
                        
                        if not @target then switch @catch
                            when 'order' #order of shapes is reversed
                                param.switchOrder()
                            when 'shape' #one shape is changed
                                param.switchShape()
                            when 'negate'
                                param.switchNegate()
                            when 'relation'
                                param.switchRelation()
                            else throw 'invalid catch type'
                    when 2
                        param = new Array(4)
                        
                        param[@target] = @root.parameter.Stimulus @prompt_param
                        
                        num_distractors = @root.parameter._num_distractors
                        for idx in [0..num_distractors-1]
                            idx_distractor = (@target + idx + 1) % (num_distractors+1)
                            
                            distractor = @root.parameter.Stimulus(param[@target])
                            
                            d_type = @["d#{idx}_type"]
                            if d_type.shape then distractor.switchShape(d_type.shape, @distractor_shape)
                            if d_type.order then distractor.switchOrder()
                            if d_type.relation then distractor.switchRelation()
                            
                            param[idx_distractor] = distractor
                
                param
        
        TrialSequence: (values=null) => new @ClassParameterTrialSequence(@root, values)
        ClassParameterTrialSequence: class window.CognitiveStyleClassParameterTrialSequence extends ExperimentClassParameterBase
            _param_values: null
            _aux_param_values: null
            
            constructor: (root, values) ->
                super root, values
                
                @_addParameter 'num_trials', @root.parameter.getDefaultNumTrials
                @_addParameter 'seed', @root.time.now
                @_addParameter 'trial_param', @_getTrialParameters
                
            _getRawTrialParameters: () =>
                rng = new Math.seedrandom @seed
                
                param_raw = @root.parameter.generate @num_trials, @root.parameter._trial_param_values,
                        aux_param_values: @root.parameter._trial_aux_param_values
                        mutually_exclusive: @root.parameter._trial_mutually_exclusive
                        rng: rng
            
            _getTrialParameters: () =>
                param = @_getRawTrialParameters()
                
                for idx in [0..param.length-1]
                    p = param[idx]
                    
                    stimulus_param = @root.parameter.Stimulus
                        shape1: p.shape1
                        shape2: p.shape2
                        relation: p.relation
                        negate: p.negate
                    
                    switch @root.version
                        when 1
                            param[idx] = @root.parameter.Trial
                                target: p.target
                                catch: p.catch
                                stimulus_param: stimulus_param
                                prompt_format: p.prompt_format
                                test_format: p.test_format
                        when 2
                            param[idx] = @root.parameter.Trial
                                target: p.target
                                distractor_order: p.distractor_order
                                distractor_shape: p.distractor_shape
                                stimulus_param: stimulus_param
                                prompt_format: p.prompt_format
                                test_format: p.test_format
                
                [param]
    
    ClassInput: class window.CognitiveStyleClassInput extends ExperimentClassInput
        constructor: (root, options) ->
            options = merge_object {
                'key_yes': root._key_yes
                'key_no': root._key_no
            }, (options ? {})
            
            super root, options
    
    ClassDo: class window.CognitiveStyleClassDo extends ExperimentClassDo
    
        Run: (options=null) => new @ClassDoRun(@root, options)
        ClassDoRun: class window.CognitiveStyleClassDoRun extends ExperimentClassDoSequence
            _sequence_param: null
            
            result: null
            
            _saving_stim: null
            
            constructor: (root, options) ->
                @root = root
                options ?= {}
                options.num_trials ?= null
                options.randomize ?= true
                options.save ?= true
                
                @_sequence_param = @root.parameter.getSequenceParam
                    num_trials: options.num_trials
                    randomize: options.randomize
                
                f = [
                    (c) => @_verifySubject(c, options)
                    (c) => @_doInstructions(c, options)
                    (c) => @_doTrials(c, options)
                ]
                
                next = ('callback' for [1..f.length])
                
                super root, f, next, options
                
                if options.save
                    @callback @_saveResults
                else
                    @callback @_saveSuccess
            
            _verifySubject: (callback, options) =>
                @root.data.read 'completed',
                    success: (result) => @_verifySubjectSuccess(result, callback)
                    error: (status, err) => @_verifySubjectError(status, err)
            _verifySubjectSuccess: (result, callback) =>
                if result.value and @root.subject != 'nobody'
                    @root.show.Text 'You have already completed this experiment.',
                        preset: 'instruction'
                else
                    callback()
            _verifySubjectError: (status, err) =>
                @root.show.Text "Error (#{status})",
                    preset: 'instruction'
            
            _doInstructions: (callback, options) =>
                seq = @root.do.Instructions options
                if callback? then seq.callback(callback)
                seq.fire()
            
            _doTrials: (callback, options) =>
                options = merge_object options, {
                    sequence_param: @_sequence_param
                }
                seq = @root.do.VVCompareTrials options
                seq.callback (result) => @result = result
                if callback? then seq.callback(callback)
                seq.fire()
            
            _saveResults: (result) =>
                @_saving_stim = @root.show.Text 'Sending results. Please wait...',
                    preset: 'instruction'
                
                @root.data.write 'result', JSON.stringify(result),
                    success: @_saveSuccess
                    error: @_saveError
            
            _saveSuccess: (result) =>
                completion_code = result['verification']
                
                @_saving_stim.remove()
                
                stim1 = @root.show.Text "You are finished!\n
                                        Your completion code is below:\n",
                    preset: 'instruction'
                
                stim2 = @root.show.Text completion_code,
                    preset: 'data'
                    color: 'blue'
                
                stim3 = @root.show.Text '(double-click on the code to select it)',
                    preset: 'instruction'
                    'font-style': 'italic'
                
                stim = @root.show.StimulusGrid [stim1, stim2, stim3],
                    cols: 1
                    padding: @root._row_padding
            
            _saveError: (status, err) =>
                @_saving_stim.remove()
                
                @root.show.Text "Error (could not connect to server to save data)",
                    preset: 'instruction'
            
            callback: (f=null) =>
                if f?
                    super => f(@result)
                else
                    super f
        
        Instructions: (options=null) => new @ClassDoInstructions(@root, options)
        ClassDoInstructions: class window.CognitiveStyleClassDoInstructions extends ExperimentClassDoSequence
            _verbal_description: null
            _choice_options: {
                type: 'key'
                key: null
                prompt_suffix: 'to continue'
            }
            _choice_final_suffix: 'to begin'
            _param: [
                {
                    shape1: 'square'
                    shape2: 'star'
                    relation: 'right'
                }
                {
                    shape1: 'circle'
                    shape2: 'plus'
                    relation: 'left'
                }
                {
                    shape1: 'star'
                    shape2: 'triangle'
                    relation: 'above'
                }
                {
                    shape1: 'plus'
                    shape2: 'square'
                    relation: 'below'
                }
            ]
            _trial_param: null
            
            constructor: (root, options) ->
                @root = root
                
                @_verbal_description = switch @root.version
                    when 1 then 'sentence'
                    when 2 then 'word list'
                @_choice_options.key = @root._advance_key
                @_trial_param = @root.parameter.Trial()
                
                f = [
                    (c) => @_doIntro(c, options)
                    (c) => @_doPracticeTrials(c, options)
                    (c) => @_doConclusion(c, options)
                ]
                
                next = ('callback' for [1..f.length])
                
                super root, f, next, options
        
            _doIntro: (callback=null, options=null) =>
                stim = [
                    @_showVisualVerbal
                    => @_showExample(0)
                    => @_showExample(1)
                    => @_showExample(2)
                    => @_showExample(3)
                    @_showTrialPrompt
                    if @root.version==1 then @_showTrialTest else @_showTrialTest2
                    => @_showPracticeTrials(options)
                ]
                
                next = (['choice', copy_object @_choice_options] for s in stim)
                next[next.length-1][1].prompt_suffix = @_choice_final_suffix
                
                seq = @root.show.Sequence stim, next
                if callback? then seq.callback(callback)
                seq.fire()
            
            _doPracticeTrials: (callback=null, options=null) =>
                options ?= {}
                options.num_practice_trials ?= @root._instruct_num_trials
                
                sequence_param = @root.parameter.TrialSequence
                    num_trials: options.num_practice_trials
                
                seq = @root.do.VVCompareTrials
                    sequence_param: sequence_param
                seq.callback @_savePracticeResults
                if callback? then seq.callback(callback)
                seq.fire()
            
            _doConclusion: (callback=null, options=null) =>
                stim = [
                    @_showTrialCatch
                    => @_showConclusion(options)
                    null
                ]
                
                next = (['choice', copy_object @_choice_options] for s in stim)
                next[next.length-2][1].prompt_suffix = @_choice_final_suffix
                next[next.length-1] = 1000
                
                seq = @root.show.Sequence stim, next
                if callback? then seq.callback callback
                seq.fire()
            
            _showVisualVerbal: () =>
                param = @root.parameter.Stimulus @_param[0]
                
                text1 = @root.show.Text "You will now complete a series of trials\n
                                        in which you compare #{@_verbal_description}s like this:", @root._instruct_text_options
                
                stim1 = @root.show.VerbalStimulus
                    stim_param: param
                
                text2 = @root.show.Text 'to pictures like this:', @root._instruct_text_options
                stim2 = @root.show.VisualStimulus
                    stim_param: param
                
                grid = @root.show.StimulusGrid [text1, stim1, text2, stim2],
                    cols: 1
                    padding: @root._row_padding
            
            _showExample: (idx) =>
                param = @_param[idx]
                
                textA = @root.show.Text "Each #{@_verbal_description} has a matching picture.\n
                                        A few examples will be shown below:", @root._instruct_text_options
                
                switch @root.version
                    when 1
                        num_cols = 1
                        padding = @root._row_padding
                    when 2
                        num_cols = 2
                        padding = @root._col_padding
                
                stim_verbal = @root.show.VerbalStimulus
                    stim_param: param
                stim_visual = @root.show.VisualStimulus
                    stim_param: param
                stim_pair = @root.show.StimulusGrid [stim_verbal, stim_visual],
                    cols: num_cols
                    padding: padding
                
                textB = @root.show.Text "Note that the first shape in the #{@_verbal_description}\n
                                        goes with the red shape in the picture.", @root._instruct_text_options
                
                @root.show.StimulusGrid [textA, stim_pair, textB],
                    cols: 1
                    padding: @root._row_padding
            
            _showTrialPrompt: () =>
                param = @_trial_param.prompt_param
                
                textA = @root.show.Text "Each trial starts with either a #{@_verbal_description}\n
                                        or a picture (example below).", @root._instruct_text_options
                textB = @root.show.Text "You can view it for as long as you need.\n
                                        When you are ready to move on, press #{@root._advance_key}.", @root._instruct_text_options
                
                stim = @root.show.VisualStimulus
                    stim_param: param
                
                grid = @root.show.StimulusGrid [textA, stim, textB],
                    cols: 1
                    padding: @root._row_padding
            
            _showTrialTest: () =>
                param = @_trial_param.test_param
                
                key_yes = @root.input.key2synonym 'yes'
                key_no = @root.input.key2synonym 'no'
                
                textA = @root.show.Text "Next, you will see another #{@_verbal_description} or picture:
                                        ", @root._instruct_text_options
                textB = @root.show.Text "Your task is to decide whether the two displays match,\n
                                        regardless of whether they were #{@_verbal_description}s or pictures.", @root._instruct_text_options
                textC = @root.show.Text "If they match, press #{key_yes}.\n
                                        If they don't match, press #{key_no}.", @root._instruct_text_options
                
                stim = @root.show.VerbalStimulus
                    stim_param: param
                
                grid = @root.show.StimulusGrid [textA, stim, textB, textC],
                    cols: 1
                    padding: @root._row_padding
            
            _showTrialTest2: () =>
                keys = @root.input.key2description @root.input._keys['4choice']
                
                textA = @root.show.Text "Next, you will see four #{@_verbal_description}s or pictures:
                                        ", @root._instruct_text_options
                textB = @root.show.Text "Your task is to choose the matching #{@_verbal_description} or picture\n
                                        by pressing #{keys}.", @root._instruct_text_options
                
                stim = (@root.show.VerbalStimulus(param) for param in @_trial_param.test_param)
                ring = @root.show.StimulusRing stim,
                    r: @root._test_ring_radius
                
                grid = @root.show.StimulusGrid [textA, ring, textB],
                    cols: 1
                    padding: @root._row_padding
            
            _showTrialCatch: () =>
                param1 = @root.parameter.Stimulus @_param[0]
                param2 = param1.copy().switchRelation().switchOrder()
                
                textA = @root.show.Text "Finally, note that you will never see two displays that\n
                                        don't match but describe the same configuration.\n
                                        For example, one of these:", @root._instruct_text_options
                
                textB = @root.show.Text "will never be followed by one of these:", @root._instruct_text_options
                
                switch @root.version
                    when 1
                        num_cols = 1
                        padding = @root._row_padding
                    when 2
                        num_cols = 2
                        padding = @root._col_padding
                
                stim1_verbal = @root.show.VerbalStimulus
                    stim_param: param1
                stim1_visual = @root.show.VisualStimulus
                    stim_param: param1
                stim1_grid = @root.show.StimulusGrid [stim1_verbal, stim1_visual],
                    cols: num_cols
                    padding: padding
                
                stim2_verbal = @root.show.VerbalStimulus
                    stim_param: param2
                stim2_visual = @root.show.VisualStimulus
                    stim_param: param2
                stim2_grid = @root.show.StimulusGrid [stim2_verbal, stim2_visual],
                    cols: num_cols
                
                grid = @root.show.StimulusGrid [textA, stim1_grid, textB, stim2_grid],
                    cols: 1
                    padding: @root._row_padding
            
            _showPracticeTrials: (options=null) =>
                options ?= {}
                options.num_practice_trials ?= @root._instruct_num_trials
                
                trial_plural = if options.num_practice_trials==1 then '' else 's'
                
                textA = @root.show.Text "After each trial, the next trial begins immediately.", @root._instruct_text_options
                textB = @root.show.Text "Now you will try #{options.num_practice_trials} practice trial#{trial_plural}.", @root._instruct_text_options
                
                grid = @root.show.StimulusGrid [textA, textB],
                    cols: 1
                    padding: @root._row_padding
            
            _showConclusion: (options=null) =>
                options ?= {}
                options.num_trials ?= @root.parameter.getDefaultNumTrials()
                options.trials_per_block ?= @root.parameter._trials_per_block
                
                trial_plural = if options.num_trials==1 then '' else 's'
                block_plural = if options.trials_per_block==1 then '' else 's'
                
                textA = @root.show.Text "The experiment will now begin.\n
                                        You will complete #{options.num_trials} trial#{trial_plural},\n
                                        and will be given a break every #{options.trials_per_block} trial#{block_plural}.", @root._instruct_text_options
            
            _savePracticeResults: (result) =>
                @root.data.write 'practice_result', JSON.stringify(result)
        
        VVCompareTrials: (options=null) => new @ClassDoVVCompareTrials(@root, options)
        ClassDoVVCompareTrials: class window.CognitiveStyleClassDoVVCompareTrials extends ExperimentClassDoAction
            result: null
            
            _sequence_param: null
            
            _counter: null
            
            _callback_ready: false
            
            constructor: (root, options) ->
                super root, => @runTrial(0)
                
                options ?= {}
                options.sequence_param ?= @root.parameter.TrialSequence()
                
                @_sequence_param = options.sequence_param
                
                @result = (null for [1..@_sequence_param.num_trials])
                
                @_counter = @root.show.Text @_trialCounter(0),
                    "text-anchor": 'start'
                    l: 4
                    t: 4
            
            runTrial: (idx) =>
                @_counter.attr 'text', @_trialCounter(idx)
                
                trial_param = @_sequence_param.trial_param[idx]
                
                trial = @root.trial.VVCompare
                    trial_param: trial_param
                trial.callback (result) => @_processTrialResult(idx, result)
                
                if idx < @_sequence_param.num_trials-1
                    next_idx = idx+1
                    block_number = next_idx / @root.parameter._trials_per_block
                    if block_number == Math.floor(block_number)
                        f_callback = => @runRest(next_idx)
                    else
                        f_callback = => @runTrial(next_idx)
                    
                    trial.callback f_callback
                else
                    trial.callback =>
                        @_callback_ready = true
                        @callback()
                
                trial.fire()
            
            runRest: (idx) =>
                trials_remaining = @_sequence_param.num_trials - idx
                trials_plural = if trials_remaining==1 then '' else 's'
                
                text_options = merge_object @root._instruct_text_options,
                    show: true
                
                text = @root.show.Text "You may now rest.\n
                                        You have #{trials_remaining} trial#{trials_plural} remaining.", text_options
                choice = @root.show.Choice [text],
                    type: 'key'
                    key: @root._advance_key
                    prompt_suffix: 'to continue'
                
                choice.callback (obj, c) => choice.remove(); @runTrial idx
            
            _trialCounter: (idx) =>
                num_trials = ''+@_sequence_param.num_trials
                current_trial = string_pad idx+1, num_trials.length
                "Trial #{current_trial} of #{num_trials}"
            
            _processTrialResult: (idx, result) =>
                @result[idx] = result
            
            callback: (f=null) =>
                if f?
                    super => f(@result)
                else
                    if @_callback_ready
                        @_counter.remove()
                        super f
    
    ClassShow: class window.CognitiveStyleClassShow extends ExperimentClassShow
        VisualStimulus: (options=null) => new @ClassShowVisualStimulus(@root, options)
        ClassShowVisualStimulus: class window.CognitiveStyleClassShowVisualStimulus extends ExperimentClassShowStimulusGrid
            _shape1: null
            _shape2: null
            _stim_param: null
            
            constructor: (root, options) ->
                @root = root
                
                options ?= {}
                
                @_stim_param = (object_extract options, 'stim_param') ? @root.parameter.Stimulus(options)
                
                @_shape1 = @_showShape1(options)
                @_shape2 = @_showShape2(options)
                
                switch @_stim_param.relation
                    when 'left', 'above'
                        shpA = @_shape1
                        shpB = @_shape2
                    when 'right', 'below'
                        shpA = @_shape2
                        shpB = @_shape1
                    else throw 'invalid relation'
                
                elements = if @_stim_param.negate then [shpB, shpA] else [shpA, shpB]
                
                super root, elements, options
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    size: @root._visual_stimulus_size
                }
                
                switch @_stim_param.relation
                    when 'left', 'right'
                        @_addDefaults {
                            rows: 1
                            cols: 2
                        }
                    when 'above', 'below'
                        @_addDefaults {
                            rows: 2
                            cols: 1
                        }
                    else throw 'invalid relation'
                
                super options
            
            _showShape1: (options) =>
                @root.show.Shape @_stim_param.shape1, merge_object options, {color: @root.parameter._colors[0]}
            
            _showShape2: (options) =>
                @root.show.Shape @_stim_param.shape2, merge_object options, {color: @root.parameter._colors[1]}
            
            attr: (name, value) ->
                switch name
                    when 'size'
                        if @attr('cols')==1
                            d1 = 'width'
                            d2 = 'height'
                        else
                            d1 = 'height'
                            d2 = 'width'
                        
                        if value?
                            super d1, value
                            super d2, 2*value+@attr('padding')
                        else
                            ret = super d1
                    else
                        ret = super name, value
                
                if value? then @ else ret
        
        VerbalStimulus: (options=null) => new @ClassShowVerbalStimulus(@root, options)
        ClassShowVerbalStimulus: class window.CognitiveStyleClassShowVerbalStimulus extends ExperimentClassShowText
            _stim_param: null
            
            constructor: (root, options) ->
                @root = root
                
                options ?= {}
                
                @_stim_param = (object_extract options, 'stim_param') ? @root.parameter.Stimulus(options)
                
                super root, @_getText(), options
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    "font-family": 'Source Code Pro'
                    "font-size": @root._verbal_stimulus_font_size
                }
                
                options = super options
            
            _getText: () =>
                shape1 = @_stim_param.shape1
                shape2 = @_stim_param.shape2
                
                relation = switch @_stim_param.relation
                    when 'left', 'right'
                        @_stim_param.relation + ' of'
                    else
                        @_stim_param.relation
                
                negate = if @_stim_param.negate then "not " else ""
                
                switch @root.version
                    when 1
                        "#{shape1} is #{negate}#{relation} #{shape2}".toUpperCase()
                    when 2 
                        "#{shape1}\n#{negate}#{relation}\n#{shape2}".toUpperCase()
        
        VisualMask: (options=null) => new @ClassShowVisualMask(@root, options)
        ClassShowVisualMask: class window.CognitiveStyleClassShowVisualMask extends CognitiveStyleClassShowVisualStimulus
            _showShape: (options) =>
                @root.show.Checkerboard
                    color1: @root.parameter._colors[0]
                    color2: @root.parameter._colors[1]
                    rows: 4
                    padding: 4
                
            _showShape1: (options) =>
                @_showShape(options)
            
            _showShape2: (options) =>
                @_showShape(options)
        
        VerbalMask: (options=null) => new @ClassShowVerbalMask(@root, options)
        ClassShowVerbalMask: class window.CognitiveStyleClassShowVerbalMask extends CognitiveStyleClassShowVerbalStimulus
            _getText: () =>
                #original text
                text = super()
                
                #just the words
                words = text.split(/[ \n]/)
                num_words = words.length
                
                #scramble just the characters
                chars = string_scramble text.replace(/[ \n]/g, '')
                space = text.replace(/[^ \n]+/g, '')
                
                #construct the new string
                text = ''
                char = 0
                for idx_word in [0..num_words-1]
                    num_chars = words[idx_word].length
                    text += chars.substring(char, char+num_chars)
                    if idx_word < num_words-1
                        text += space[idx_word]
                    char += num_chars
                
                text
        
        ShapeStimuli: (options=null) => new @ClassShowShapeStimuli(@root, options)
        ClassShowShapeStimuli: class window.CognitiveStyleClassShowShapeStimuli extends ExperimentClassShowStimulusGrid
            constructor: (root, options) ->
                @root = root
                
                shape_stims = []
                for shape in @root.parameter._shapes
                    s = @root.show.VisualStimulus
                        shape1: shape
                        shape2: shape
                        relation: 'above'
                    label = @root.show.Text shape,
                        preset: 'instruction'
                    grid = @root.show.StimulusGrid [s, label],
                        rows: 2
                    
                    shape_stims.push grid
                
                super root, shape_stims, options
            
            _prepareOptions: (options) ->
                @_addDefaults {
                    padding: @root._row_padding
                }
                
                super options
    
    ClassTrial: class window.CognitiveStyleClassTrial extends ExperimentClassTrial
        VVCompare: (options=null) => new @ClassTrialVVCompare(@root, options)
        ###
            options:
                
        ###
        ClassTrialVVCompare: class window.CognitiveStyleClassTrialVVCompare extends ExperimentClassTrialBase
            _intertrial_time: 1000
            _warning_time: 500
            _maskflanker_time: 50
            _delay_time: 400
            _feedback_time: 500
            
            _step_encode: null
            _step_verify: null
            
            _trial_param: null
            
            constructor: (root, options) ->
                @root = root
                
                options = merge_object {
                    trial_param: null
                    prompt_param: null
                    test_group_options: {r: @root._test_ring_radius}
                }, (options ? {})
                
                @_trial_param = options.trial_param ? @root.parameter.Trial()
                
                options.target = @_trial_param.target
                
                super root, options
            
            _getSequenceStim: (options) =>
                #generate the prompt stimulus
                prompt_generator = capitalize(@_trial_param.prompt_format)+'Stimulus'
                prompt = @root.show[prompt_generator]
                    stim_param: @_trial_param.prompt_param
                    show: false
                
                switch @root.version
                    when 1
                        #generate the mask stimulus
                        mask_generator = capitalize(@_trial_param.prompt_format)+'Mask'
                        mask = @root.show[mask_generator]
                            stim_param: @_trial_param.prompt_param
                            show: false
                        
                        stim = [
                            null
                            ['Circle', {r:8}]
                            prompt
                            null
                            mask
                            null
                        ]
                    when 2
                        stim = [
                            null
                            ['Circle', {r:8}]
                            prompt
                            #null
                        ]
                
                @_step_encode = find(stim, prompt, 1)[0]
                @_step_verify = stim.length
                
                stim
            
            _getSequenceNext: (sequence_stim, options) =>
                prompt_next = ['choice',
                        type:'key'
                        key:@root._advance_key
                        prompt: "Press #{@root.input.key2description(@root._advance_key)} to continue."
                    ]
                
                switch @root.version
                    when 1
                        [
                            @_intertrial_time
                            @_warning_time
                            prompt_next
                            @_maskflanker_time
                            @_delay_time
                            @_maskflanker_time
                        ]
                    when 2
                        [
                            @_intertrial_time
                            @_warning_time
                            prompt_next
                            #@_delay_time + 2*@_maskflanker_time
                        ]
            
            _getTestStim: (options) =>
                #generate the test stimulus
                test_generator = capitalize(@_trial_param.test_format)+'Stimulus'
                stim_param = @_trial_param.test_param
                switch @root.version
                    when 1
                        [[test_generator, {stim_param:stim_param}]]
                    when 2
                        ( [test_generator, {stim_param:p}] for p in stim_param )
            
            getResult: () =>
                full_result = super()
                
                result = {
                    t_show: (obj.t.show for obj in full_result)
                    t_remove: (obj.t.remove for obj in full_result)
                    param: @_trial_param.toObject()
                    encoding_rt: full_result[@_step_encode].rt
                    verification_rt: full_result[@_step_verify].rt
                    target: full_result[@_step_verify].target
                    choice: full_result[@_step_verify].choice
                    correct: full_result[@_step_verify].correct
                }
