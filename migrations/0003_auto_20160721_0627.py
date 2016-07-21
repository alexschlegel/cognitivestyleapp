# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('cognitivestyleapp', '0002_auto_20160720_0724'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='cognitivestylerecord',
            name='osivq',
        ),
        migrations.RemoveField(
            model_name='cognitivestylerecord',
            name='vviq',
        ),
        migrations.RemoveField(
            model_name='cognitivestylerecord',
            name='vvq',
        ),
    ]
