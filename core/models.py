from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone
import stripe
from django.conf import settings
from datetime import datetime

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    customer_id = models.CharField(max_length=100, blank=True, null=True)
    subscription_id = models.CharField(max_length=100, blank=True, null=True)
    subscription_end_date = models.DateTimeField(null=True, blank=True)
    is_cancelled = models.BooleanField(default=False)

    def can_delete_account(self):
        """
        Check if the user can delete their account.
        Returns False if they have an active subscription that hasn't been cancelled,
        or if they have a cancelled subscription that hasn't expired yet.
        """
        if not self.subscription_id:
            return True
        
        if self.subscription_end_date:
            return self.is_cancelled and self.subscription_end_date < timezone.now()
        
        return not self.subscription_id

    def save(self, *args, **kwargs):
        if self.subscription_id and not self.subscription_end_date:
            # Set subscription end date when subscription is created
            try:
                stripe.api_key = settings.STRIPE_SECRET_KEY
                subscription = stripe.Subscription.retrieve(self.subscription_id)
                self.subscription_end_date = datetime.fromtimestamp(subscription.current_period_end)
            except stripe.error.StripeError:
                pass
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.user.username}'s Profile"

    def has_active_subscription(self):
        return self.subscription_status == 'active' and self.subscription_end_date and self.subscription_end_date > timezone.now()

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    if created:
        UserProfile.objects.create(user=instance)

@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    instance.userprofile.save()
