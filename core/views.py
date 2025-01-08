from django.shortcuts import render, redirect
from django.contrib.auth import login, authenticate, logout
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.contrib import messages
from django.conf import settings
from django.http import JsonResponse
from django.utils import timezone
import stripe
import json

stripe.api_key = settings.STRIPE_SECRET_KEY

def index(request):
    return render(request, 'core/index.html', {
        'STRIPE_PUBLISHABLE_KEY': settings.STRIPE_PUBLISHABLE_KEY
    })

def login_view(request):
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        if user is not None:
            login(request, user)
            return redirect('dashboard')
        else:
            messages.error(request, 'Invalid credentials')
    return render(request, 'core/login.html')

def register_view(request):
    if request.method == 'POST':
        email = request.POST.get('email')
        username = request.POST.get('username')
        password = request.POST.get('password')
        confirm_password = request.POST.get('confirm_password')
        
        if password != confirm_password:
            messages.error(request, 'Passwords do not match')
            return render(request, 'core/register.html')
            
        if User.objects.filter(email=email).exists():
            messages.error(request, 'Email already exists')
            return render(request, 'core/register.html')
            
        if User.objects.filter(username=username).exists():
            messages.error(request, 'Username already exists')
            return render(request, 'core/register.html')
            
        user = User.objects.create_user(username=username, email=email, password=password)
        authenticated_user = authenticate(request, username=username, password=password)
        if authenticated_user is not None:
            login(request, authenticated_user)
            return redirect('dashboard')
        
    return render(request, 'core/register.html')

@login_required
def dashboard(request):
    user_profile = request.user.userprofile
    context = {
        'subscription_active': user_profile.subscription_id is not None,
        'subscription_end_date': user_profile.subscription_end_date,
        'is_cancelled': user_profile.is_cancelled,
        'can_delete_account': user_profile.can_delete_account(),
        'STRIPE_PUBLISHABLE_KEY': settings.STRIPE_PUBLISHABLE_KEY
    }
    return render(request, 'core/dashboard.html', context)

@login_required
def create_subscription(request):
    if request.method == 'POST':
        try:
            stripe.api_key = settings.STRIPE_SECRET_KEY
            data = json.loads(request.body)
            payment_method_id = data.get('payment_method_id')
            
            # Create or get Stripe customer
            if not request.user.userprofile.customer_id:
                customer = stripe.Customer.create(
                    email=request.user.email,
                    payment_method=payment_method_id,
                    invoice_settings={'default_payment_method': payment_method_id}
                )
                request.user.userprofile.customer_id = customer.id
                request.user.userprofile.save()
            else:
                customer = stripe.Customer.retrieve(request.user.userprofile.customer_id)
                stripe.PaymentMethod.attach(payment_method_id, customer=customer.id)
                stripe.Customer.modify(
                    customer.id,
                    invoice_settings={'default_payment_method': payment_method_id}
                )

            # First create a product
            product = stripe.Product.create(
                name='TikTok Auto Commenter Pro Monthly Subscription'
            )

            # Then create a price
            price = stripe.Price.create(
                product=product.id,
                unit_amount=settings.SUBSCRIPTION_PRICE_AMOUNT,
                currency='usd',
                recurring={'interval': 'month'}
            )

            # Create subscription
            subscription = stripe.Subscription.create(
                customer=request.user.userprofile.customer_id,
                items=[{'price': price.id}],
                payment_behavior='default_incomplete',
                expand=['latest_invoice.payment_intent'],
                payment_settings={'payment_method_types': ['card']}
            )
            
            request.user.userprofile.subscription_id = subscription.id
            request.user.userprofile.subscription_end_date = timezone.now() + timezone.timedelta(days=30)
            request.user.userprofile.is_cancelled = False
            request.user.userprofile.save()
            
            return JsonResponse({
                'subscription': subscription.id,
                'client_secret': subscription.latest_invoice.payment_intent.client_secret
            })
            
        except stripe.error.StripeError as e:
            return JsonResponse({'error': str(e)}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)
    
    return JsonResponse({'error': 'Invalid request method'}, status=400)

@login_required
def cancel_subscription(request):
    if request.method == 'POST':
        user_profile = request.user.userprofile
        if user_profile.subscription_id and not user_profile.is_cancelled:
            try:
                stripe.api_key = settings.STRIPE_SECRET_KEY
                subscription = stripe.Subscription.retrieve(user_profile.subscription_id)
                # Cancel at period end
                stripe.Subscription.modify(
                    user_profile.subscription_id,
                    cancel_at_period_end=True
                )
                user_profile.is_cancelled = True
                user_profile.save()
                messages.success(request, 'Your subscription has been cancelled. You will have access until the end of your billing period.')
            except stripe.error.StripeError as e:
                messages.error(request, f'Error cancelling subscription: {str(e)}')
        else:
            messages.error(request, 'No active subscription found.')
    return redirect('dashboard')

@login_required
def delete_account(request):
    if request.method == 'POST':
        user = request.user
        user_profile = user.userprofile
        if not user_profile.can_delete_account():
            messages.error(request, 'You cannot delete your account while having an active subscription. Please cancel your subscription and wait until it expires.')
            return redirect('dashboard')
        
        try:
            if user_profile.customer_id:
                stripe.api_key = settings.STRIPE_SECRET_KEY
                # Delete the customer in Stripe
                stripe.Customer.delete(user_profile.customer_id)
            
            # Delete the user account
            user.delete()
            messages.success(request, 'Your account has been successfully deleted.')
            return redirect('index')
        except stripe.error.StripeError as e:
            messages.error(request, f'Error deleting account: {str(e)}')
            return redirect('dashboard')
    return redirect('dashboard')

def logout_view(request):
    logout(request)
    return redirect('login')
