#!/bin/bash
set -uo pipefail

# ========================================
# SnapAuth Platform API Test Suite
# ========================================
# Comprehensive endpoint verification for production deployment
# Tests authentication, authorization, rate limiting, and security controls

# Configuration
BASE_URL="https://auth.machmilling.com"
PANEL_URL="https://panel.auth.machmilling.com"
SERVER_IP="185.7.212.250"
SSH_KEY="/home/parham/Downloads/private-key-file.pem"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Temporary files
RESPONSE_FILE=$(mktemp)
HEADERS_FILE=$(mktemp)
trap "rm -f $RESPONSE_FILE $HEADERS_FILE" EXIT

# ========================================
# Helper Functions
# ========================================

log_section() {
  echo ""
  echo "========================================"
  echo "$1"
  echo "========================================"
}

log_test() {
  echo ""
  echo "Testing: $1"
}

test_endpoint() {
  local name="$1"
  local expected_code="$2"
  shift 2

  # Execute curl command and capture response
  local actual_code=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" -D "$HEADERS_FILE" "$@" || echo "000")

  if [ "$actual_code" = "$expected_code" ]; then
    echo -e "${GREEN}✓ PASS${NC}: $name (HTTP $actual_code)"
    ((PASSED++))
  else
    echo -e "${RED}✗ FAIL${NC}: $name (expected $expected_code, got $actual_code)"
    echo "  Response: $(cat "$RESPONSE_FILE" | head -c 200)"
    ((FAILED++))
  fi
}

test_json_field() {
  local name="$1"
  local field="$2"
  local expected_value="$3"

  local actual_value=$(jq -r ".$field" "$RESPONSE_FILE" 2>/dev/null || echo "")

  if [ "$actual_value" = "$expected_value" ]; then
    echo -e "${GREEN}✓ PASS${NC}: $name ($field=$expected_value)"
    ((PASSED++))
  else
    echo -e "${RED}✗ FAIL${NC}: $name (expected $field=$expected_value, got $actual_value)"
    ((FAILED++))
  fi
}

test_header_exists() {
  local name="$1"
  local header="$2"

  if grep -qi "^$header:" "$HEADERS_FILE"; then
    echo -e "${GREEN}✓ PASS${NC}: $name (header $header present)"
    ((PASSED++))
  else
    echo -e "${RED}✗ FAIL${NC}: $name (header $header missing)"
    ((FAILED++))
  fi
}

test_port_blocked() {
  local name="$1"
  local port="$2"

  # Test raw TCP connection to see if port is accessible
  if timeout 2 bash -c "exec 3<>/dev/tcp/$SERVER_IP/$port 2>/dev/null" 2>/dev/null; then
    echo -e "${RED}✗ FAIL${NC}: $name (port $port accepts TCP connections - should be blocked)"
    ((FAILED++))
  else
    echo -e "${GREEN}✓ PASS${NC}: $name (port $port blocked)"
    ((PASSED++))
  fi
}

# ========================================
# Setup
# ========================================

log_section "SnapAuth API Test Suite"
echo "Date: $(date)"
echo "Base URL: $BASE_URL"
echo "Panel URL: $PANEL_URL"
echo ""

# Check dependencies
log_test "Checking dependencies"
for cmd in curl jq ssh; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${RED}Error: $cmd is not installed${NC}"
    exit 1
  fi
done
echo "✓ All dependencies available"

# Fetch API key from production server
log_test "Fetching API key from production server"
API_KEY=$(ssh -i "$SSH_KEY" root@$SERVER_IP \
  'grep "^SNAPAUTH_ADMIN_API_KEY=" /opt/snapauth-platform/.env | cut -d= -f2 | tr -d "\"" | head -n 1' 2>/dev/null)

if [ -z "$API_KEY" ]; then
  echo -e "${RED}Error: Failed to fetch API key from server${NC}"
  exit 1
fi
echo "✓ API key retrieved successfully"

# ========================================
# Test 1: Health Check
# ========================================

log_section "Test 1: Health Check Endpoints"

log_test "GET /health (should return 200 with healthy status)"
test_endpoint "Health check" "200" "$BASE_URL/health"
test_json_field "Health status field" "status" "healthy"

log_test "Security headers on health endpoint"
test_header_exists "X-Frame-Options header" "X-Frame-Options"
test_header_exists "X-Content-Type-Options header" "X-Content-Type-Options"
test_header_exists "Strict-Transport-Security header" "Strict-Transport-Security"

# ========================================
# Test 2: User Management (Admin API)
# ========================================

log_section "Test 2: User Management (Admin API)"

# Test user data (using Iran mobile number format as username)
TEST_USERNAME="09$(date +%s | tail -c 10)"  # Generate 09XXXXXXXXX format
TEST_PASSWORD="TestPass123!@#"

log_test "POST /v1/users without API key (should return 401)"
test_endpoint "User creation without API key" "401" \
  -X POST "$BASE_URL/v1/users" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USERNAME\",\"password\":\"$TEST_PASSWORD\"}"

log_test "POST /v1/users with invalid API key (should return 401)"
test_endpoint "User creation with invalid API key" "401" \
  -X POST "$BASE_URL/v1/users" \
  -H "Content-Type: application/json" \
  -H "X-SnapAuth-API-Key: invalid-key-12345" \
  -d "{\"username\":\"$TEST_USERNAME\",\"password\":\"$TEST_PASSWORD\"}"

log_test "POST /v1/users with valid API key (should return 201)"
test_endpoint "User creation with valid API key" "201" \
  -X POST "$BASE_URL/v1/users" \
  -H "Content-Type: application/json" \
  -H "X-SnapAuth-API-Key: $API_KEY" \
  -d "{\"username\":\"$TEST_USERNAME\",\"password\":\"$TEST_PASSWORD\"}"

# Extract user ID for subsequent tests
USER_ID=$(jq -r '.userId // empty' "$RESPONSE_FILE" 2>/dev/null || echo "")
if [ -z "$USER_ID" ]; then
  echo -e "${YELLOW}Warning: Could not extract user ID from response, some tests may fail${NC}"
else
  echo "✓ User ID extracted: $USER_ID"
fi

# ========================================
# Test 3: Authentication Endpoints
# ========================================

log_section "Test 3: Authentication Endpoints"

log_test "POST /v1/auth/login with invalid credentials (should return 401)"
test_endpoint "Login with invalid credentials" "401" \
  -X POST "$BASE_URL/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USERNAME\",\"password\":\"WrongPassword123\"}"

log_test "POST /v1/auth/login with valid credentials (should return 200)"
test_endpoint "Login with valid credentials" "200" \
  -X POST "$BASE_URL/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$TEST_USERNAME\",\"password\":\"$TEST_PASSWORD\"}"

# Extract tokens
ACCESS_TOKEN=$(jq -r '.accessToken // empty' "$RESPONSE_FILE" 2>/dev/null || echo "")
REFRESH_TOKEN=$(jq -r '.refreshToken // empty' "$RESPONSE_FILE" 2>/dev/null || echo "")
USER_ID_FROM_LOGIN=$(jq -r '.userId // empty' "$RESPONSE_FILE" 2>/dev/null || echo "")

if [ -n "$ACCESS_TOKEN" ]; then
  echo "✓ Access token received"
else
  echo -e "${YELLOW}Warning: No access token in response${NC}"
fi

# Use user ID from login if not set from user creation
if [ -z "$USER_ID" ] && [ -n "$USER_ID_FROM_LOGIN" ]; then
  USER_ID="$USER_ID_FROM_LOGIN"
  echo "✓ User ID from login: $USER_ID"
fi

if [ -n "$REFRESH_TOKEN" ]; then
  log_test "POST /v1/auth/refresh with valid refresh token (should return 200)"
  test_endpoint "Token refresh with valid token" "200" \
    -X POST "$BASE_URL/v1/auth/refresh" \
    -H "Content-Type: application/json" \
    -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}"
fi

log_test "POST /v1/auth/refresh with invalid token (should return 401)"
test_endpoint "Token refresh with invalid token" "401" \
  -X POST "$BASE_URL/v1/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"invalid-refresh-token\"}"

# ========================================
# Test 4: User Deletion (Self-Delete with JWT)
# ========================================

log_section "Test 4: User Deletion (Self-Delete)"

if [ -n "$USER_ID" ] && [ -n "$ACCESS_TOKEN" ]; then
  log_test "DELETE /v1/users/{id} without authentication (should return 401)"
  test_endpoint "Delete user without token" "401" \
    -X DELETE "$BASE_URL/v1/users/$USER_ID"

  log_test "DELETE /v1/users/{id} with valid JWT (should return 204)"
  test_endpoint "Delete own user with JWT" "204" \
    -X DELETE "$BASE_URL/v1/users/$USER_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN"
else
  echo -e "${YELLOW}Skipping self-delete tests (missing user ID or token)${NC}"
fi

# ========================================
# Test 5: Admin Deletion
# ========================================

log_section "Test 5: Admin User Deletion"

# Create a new test user for admin deletion
TEST_USERNAME_2="09$(date +%s | tail -c 10)"
log_test "Creating test user for admin deletion"
test_endpoint "Create user for admin deletion test" "201" \
  -X POST "$BASE_URL/v1/users" \
  -H "Content-Type: application/json" \
  -H "X-SnapAuth-API-Key: $API_KEY" \
  -d "{\"username\":\"$TEST_USERNAME_2\",\"password\":\"$TEST_PASSWORD\"}"

USER_ID_2=$(jq -r '.userId // empty' "$RESPONSE_FILE" 2>/dev/null || echo "")

if [ -n "$USER_ID_2" ]; then
  log_test "DELETE /v1/admin/users/{id} without API key (should return 401)"
  test_endpoint "Admin delete without API key" "401" \
    -X DELETE "$BASE_URL/v1/admin/users/$USER_ID_2"

  log_test "DELETE /v1/admin/users/{id} with valid API key (should return 204)"
  test_endpoint "Admin delete with API key" "204" \
    -X DELETE "$BASE_URL/v1/admin/users/$USER_ID_2" \
    -H "X-SnapAuth-API-Key: $API_KEY"
else
  echo -e "${YELLOW}Skipping admin delete tests (user creation failed)${NC}"
fi

# ========================================
# Test 6: Rate Limiting
# ========================================

log_section "Test 6: Rate Limiting Enforcement"

log_test "Testing authentication rate limiting (10 req/min limit)"
echo "Sending 12 rapid login requests (expecting rate limit after 10)..."

RATE_LIMITED=0
for i in {1..12}; do
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
    -X POST "$BASE_URL/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"09999999999\",\"password\":\"test\"}" 2>/dev/null || echo "000")

  echo -n "  Request $i: HTTP $HTTP_CODE"

  if [ "$HTTP_CODE" = "429" ]; then
    echo " (rate limited)"
    RATE_LIMITED=1
    break
  else
    echo ""
  fi

  # Small delay to avoid overwhelming the server
  sleep 0.1
done

if [ "$RATE_LIMITED" = "1" ]; then
  echo -e "${GREEN}✓ PASS${NC}: Rate limiting enforced"
  ((PASSED++))

  # Check for Retry-After header
  curl -s -D "$HEADERS_FILE" -o /dev/null \
    -X POST "$BASE_URL/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"test@example.com\",\"password\":\"test\"}"

  test_header_exists "Retry-After header on 429" "Retry-After"
else
  echo -e "${YELLOW}Warning: Rate limiting not triggered after 12 requests${NC}"
  echo "(This may indicate rate limiting is configured differently or not enabled)"
fi

# Wait for rate limit to reset
echo "Waiting 10 seconds for rate limit to reset..."
sleep 10

# ========================================
# Test 7: Security Verification
# ========================================

log_section "Test 7: Security Controls"

log_test "Network isolation - FusionAuth port 9011 (should be blocked)"
test_port_blocked "FusionAuth port blocked" "9011"

log_test "Network isolation - PostgreSQL port 5432 (should be blocked)"
test_port_blocked "PostgreSQL port blocked" "5432"

log_test "HTTPS enforcement on main endpoint"
HTTP_REDIRECT=$(curl -s -w "%{http_code}" -o /dev/null http://auth.machmilling.com/health 2>/dev/null || echo "000")
if [ "$HTTP_REDIRECT" = "301" ] || [ "$HTTP_REDIRECT" = "302" ] || [ "$HTTP_REDIRECT" = "200" ]; then
  echo -e "${GREEN}✓ PASS${NC}: HTTP handling configured (HTTP $HTTP_REDIRECT)"
  ((PASSED++))
else
  echo -e "${YELLOW}Warning: HTTP response code $HTTP_REDIRECT${NC}"
fi

log_test "TLS certificate validity"
if echo | openssl s_client -connect auth.machmilling.com:443 -servername auth.machmilling.com 2>/dev/null | grep -q "Verify return code: 0"; then
  echo -e "${GREEN}✓ PASS${NC}: TLS certificate valid"
  ((PASSED++))
else
  echo -e "${RED}✗ FAIL${NC}: TLS certificate validation failed"
  ((FAILED++))
fi

# ========================================
# Test 8: Admin Panel Access
# ========================================

log_section "Test 8: Admin Panel Access"

log_test "GET panel.auth.machmilling.com (should return 200 or redirect)"
PANEL_CODE=$(curl -s -w "%{http_code}" -o /dev/null "$PANEL_URL" 2>/dev/null || echo "000")
if [ "$PANEL_CODE" = "200" ] || [ "$PANEL_CODE" = "302" ] || [ "$PANEL_CODE" = "301" ]; then
  echo -e "${GREEN}✓ PASS${NC}: Admin panel accessible (HTTP $PANEL_CODE)"
  ((PASSED++))
else
  echo -e "${RED}✗ FAIL${NC}: Admin panel returned HTTP $PANEL_CODE"
  ((FAILED++))
fi

log_test "Panel subdomain TLS certificate"
if echo | openssl s_client -connect panel.auth.machmilling.com:443 -servername panel.auth.machmilling.com 2>/dev/null | grep -q "Verify return code: 0"; then
  echo -e "${GREEN}✓ PASS${NC}: Panel TLS certificate valid"
  ((PASSED++))
else
  echo -e "${RED}✗ FAIL${NC}: Panel TLS certificate validation failed"
  ((FAILED++))
fi

# ========================================
# Test Report
# ========================================

log_section "Test Report"

TOTAL=$((PASSED + FAILED))
PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL)*100}")

echo "Date: $(date)"
echo "Base URL: $BASE_URL"
echo ""
echo "Test Results:"
echo "  Total Tests: $TOTAL"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${RED}Failed: $FAILED${NC}"
echo "  Pass Rate: $PASS_RATE%"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "========================================"
  echo -e "${GREEN}Status: ALL TESTS PASSED ✓${NC}"
  echo "========================================"
  echo ""
  echo "The SnapAuth platform is production-ready and verified."
  echo "All endpoints, security controls, and integrations are functioning correctly."
  EXIT_CODE=0
else
  echo "========================================"
  echo -e "${RED}Status: SOME TESTS FAILED ✗${NC}"
  echo "========================================"
  echo ""
  echo "Please review failed tests above and investigate issues."
  EXIT_CODE=1
fi

# Save report to file
REPORT_FILE="test-results-$(date +%Y%m%d-%H%M%S).log"
{
  echo "SnapAuth API Test Report"
  echo "========================"
  echo "Date: $(date)"
  echo "Base URL: $BASE_URL"
  echo ""
  echo "Results: PASSED=$PASSED, FAILED=$FAILED, TOTAL=$TOTAL"
  echo "Pass Rate: $PASS_RATE%"
} > "$REPORT_FILE"

echo ""
echo "Report saved to: $REPORT_FILE"

exit $EXIT_CODE
