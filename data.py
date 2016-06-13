"""
@author:    Alex Schlegel (schlegel@gmail.com).
created on: 2016-04-26

copyright 2016 Alex Schlegel (schlegel@gmail.com).  all rights reserved.
"""
import json, hmac

from django.conf import settings
from cognitivestyleapp.models import CognitiveStyleRecord

def process_request(request):
    result = {
        'success': False,
        'status': 'none'
    }
    
    safe_method = False
    if request.method == 'GET':
        data = request.GET
    elif request.method == 'POST':
        data = request.POST
        safe_method = True
    else:
        return result
    
    if 'subject' in data:
        subject = data['subject']
        
        try:
            record = CognitiveStyleRecord.objects.get(subject=subject)
        except:
            if safe_method:
                record = CognitiveStyleRecord.objects.create(subject=subject)
            else:
                result['status'] = 'unsafe method'
                return result
    else:
        result['status'] = 'no subject'
        return result
        
    
    if 'action' in data and 'key' in data:
        action = result['action'] = data['action']
        key = result['key'] = data['key']
        
        if action == 'read':
            read(record, key, result)
        elif action == 'write' and 'value' in data:
            try:
                value = result['value'] = json.loads(data['value'])
                do_write = True
            except:
                result['status'] = 'invalid json'
                do_write = False
            
            if do_write:
                write(record, key, value, result, safe_method)
        else:
            result['status'] = 'malformed action'
    else:
        result['status'] = 'malformed action'
    
    return result


def read(record, key, result):
    if hasattr(record, key):
        result['value'] = getattr(record, key)
        result['status'] = 'read'
        result['success'] = True
    else:
        result['value'] = None
        result['status'] = 'bad key'

def write(record, key, value, result, safe_method):
    if not safe_method:
        result['status'] = 'unsafe method'
    elif hasattr(record, key):
        setattr(record, key, value)
        
        verification_code = generate_verification_code(value)
        
        #save the completion code
        if key=='result':
            record.completion_code = verification_code
        
        record.save()
        
        result['verification'] = verification_code
        result['status'] = 'write'
        result['success'] = True
    else:
        result['status'] = 'bad key'

def generate_verification_code(x):
    str = json.dumps(x)
    h = hmac.new(bytearray(settings.SECRET_KEY, "ASCII"), bytearray(str, "ASCII"))
    return h.hexdigest()
