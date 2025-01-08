from django.http import JsonResponse
from django.contrib.auth import authenticate
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
import json

@csrf_exempt
@require_http_methods(["POST"])
def verify_auth(request):
    try:
        data = json.loads(request.body)
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return JsonResponse({
                'success': False,
                'message': 'Username and password are required'
            }, status=400)
        
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            # Check if user has an active subscription
            profile = user.userprofile
            has_subscription = (
                profile.subscription_id and 
                profile.subscription_end_date and 
                profile.subscription_end_date > timezone.now()
            )
            
            if has_subscription:
                # Create or get token
                token, _ = Token.objects.get_or_create(user=user)
                return JsonResponse({
                    'success': True,
                    'has_subscription': True,
                    'token': token.key,
                    'subscription_end_date': profile.subscription_end_date.isoformat(),
                    'is_cancelled': profile.is_cancelled
                })
            else:
                return JsonResponse({
                    'success': False,
                    'message': 'No active subscription found'
                })
        else:
            return JsonResponse({
                'success': False,
                'message': 'Invalid credentials'
            })
            
    except json.JSONDecodeError:
        return JsonResponse({
            'success': False,
            'message': 'Invalid JSON data'
        }, status=400)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'message': str(e)
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_subscription(request):
    try:
        profile = request.user.userprofile
        has_subscription = (
            profile.subscription_id and 
            profile.subscription_end_date and 
            profile.subscription_end_date > timezone.now()
        )
        
        if has_subscription:
            return JsonResponse({
                'success': True,
                'subscription_active': True,
                'subscription_end_date': profile.subscription_end_date.isoformat(),
                'is_cancelled': profile.is_cancelled
            })
        else:
            return JsonResponse({
                'success': False,
                'subscription_active': False,
                'message': 'No active subscription found'
            }, status=403)
            
    except Exception as e:
        return JsonResponse({
            'success': False,
            'message': str(e)
        }, status=500) 