import json

from django.http import HttpResponse
from django.views.generic.base import TemplateView
from django.contrib.auth.decorators import login_required
from django.shortcuts import render

from cognitivestyleapp import data

def data_view(request):
	result = data.process_request(request)
	return HttpResponse(json.dumps(result), content_type='application/json')

class VVCompare(TemplateView):
    template_name = "cognitivestyleapp/vvcompare.html"

    def get_context_data(self, **kwargs):
        context = super(VVCompare, self).get_context_data(**kwargs)
        return context

