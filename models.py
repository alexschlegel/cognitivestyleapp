from django.db import models

class CognitiveStyleRecord(models.Model):
    subject = models.CharField(max_length=64, primary_key=True)
    result = models.TextField()
    practice_result = models.TextField()
    completion_code = models.CharField(max_length=32)
    
    @property
    def completed(self):
        return len(self.completion_code) > 0
