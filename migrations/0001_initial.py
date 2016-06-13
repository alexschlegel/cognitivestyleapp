# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='CognitiveStyleRecord',
            fields=[
                ('subject', models.CharField(max_length=64, primary_key=True, serialize=False)),
                ('result', models.TextField()),
                ('practice_result', models.TextField()),
                ('completion_code', models.CharField(max_length=32)),
            ],
        ),
    ]
