from django.urls import path
from . import views
from . import api

urlpatterns = [
    # Web interface URLs
    path('', views.index, name='index'),
    path('login/', views.login_view, name='login'),
    path('register/', views.register_view, name='register'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('logout/', views.logout_view, name='logout'),
    path('create-subscription/', views.create_subscription, name='create_subscription'),
    path('cancel-subscription/', views.cancel_subscription, name='cancel_subscription'),
    path('delete-account/', views.delete_account, name='delete_account'),
    
    # API endpoints
    path('api/auth/verify/', api.verify_auth, name='api_verify_auth'),
    path('api/subscription/check/', api.check_subscription, name='api_check_subscription'),
] 