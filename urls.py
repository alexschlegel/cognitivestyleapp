from django.conf.urls import patterns, url
from django.contrib.auth.decorators import login_required
from django.contrib.auth.views import login, logout
from django.views.generic.base import RedirectView

from cognitivestyleapp import views

urlpatterns = patterns('',
    url(r'^$', views.VVCompare.as_view(), name='vvcompare'),
    url(r'^data/$', views.data_view, name='data'),
)
