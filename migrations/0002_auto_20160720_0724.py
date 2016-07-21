# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('cognitivestyleapp', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='cognitivestylerecord',
            name='osivq',
            field=models.TextField(default='hi'),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='cognitivestylerecord',
            name='vviq',
            field=models.TextField(default='hi'),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='cognitivestylerecord',
            name='vvq',
            field=models.TextField(default='hi'),
            preserve_default=False,
        ),
    ]
