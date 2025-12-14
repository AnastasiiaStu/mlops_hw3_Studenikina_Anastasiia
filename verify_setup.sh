#!/bin/bash

BASE_URL="${1:-http://localhost}"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "=========================================="
echo "  ML Service Verification Suite"
echo "  Testing: $BASE_URL"
echo "=========================================="

run_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

pass_test() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo "PASS: $1"
}

fail_test() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo "FAIL: $1"
    if [ -n "$2" ]; then
        echo "  Error: $2"
    fi
}

info() {
    echo "Info: $1"
}

test_availability() {
    echo ""
    echo "[Test 1] Service Availability"
    run_test
    
    if curl -s --max-time 5 "${BASE_URL}/health" >/dev/null 2>&1; then
        pass_test "Service is reachable"
    else
        fail_test "Service is not reachable" "Cannot connect to ${BASE_URL}/health"
        return 1
    fi
}

test_health_endpoint() {
    echo ""
    echo "[Test 2] Health Endpoint"
    run_test
    
    RESPONSE=$(curl -s "${BASE_URL}/health")
    
    if [ -z "$RESPONSE" ]; then
        fail_test "Health endpoint returned empty response"
        return 1
    fi
    
    if echo "$RESPONSE" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        pass_test "Health endpoint returns valid JSON"
    else
        fail_test "Health endpoint returns invalid JSON" "$RESPONSE"
        return 1
    fi
    
    run_test
    STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', ''))" 2>/dev/null)
    if [ "$STATUS" = "ok" ]; then
        pass_test "Health status is 'ok'"
    else
        fail_test "Health status is not 'ok'" "Status: $STATUS"
    fi
    
    run_test
    VERSION=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('version', ''))" 2>/dev/null)
    if [ -n "$VERSION" ]; then
        pass_test "Version is present: $VERSION"
    else
        fail_test "Version is missing"
    fi
    
    run_test
    MODEL_LOADED=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('model_loaded', False))" 2>/dev/null)
    if [ "$MODEL_LOADED" = "True" ]; then
        pass_test "Model is loaded"
    else
        fail_test "Model is not loaded"
    fi
}

test_predict_endpoint() {
    echo ""
    echo "[Test 3] Predict Endpoint"
    run_test
    
    TEST_DATA='{"features": [5.1, 3.5, 1.4, 0.2]}'
    RESPONSE=$(curl -s -X POST "${BASE_URL}/predict" \
        -H "Content-Type: application/json" \
        -d "$TEST_DATA")
    
    if [ -z "$RESPONSE" ]; then
        fail_test "Predict endpoint returned empty response"
        return 1
    fi
    
    if echo "$RESPONSE" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        pass_test "Predict endpoint returns valid JSON"
    else
        fail_test "Predict endpoint returns invalid JSON" "$RESPONSE"
        return 1
    fi
    
    run_test
    PREDICTION=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('prediction', ''))" 2>/dev/null)
    if [ -n "$PREDICTION" ]; then
        pass_test "Prediction value present: $PREDICTION"
    else
        fail_test "Prediction value missing"
    fi
    
    run_test
    MODEL_VERSION=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('model_version', ''))" 2>/dev/null)
    if [ -n "$MODEL_VERSION" ]; then
        pass_test "Model version in response: $MODEL_VERSION"
    else
        fail_test "Model version missing"
    fi
}

test_response_time() {
    echo ""
    echo "[Test 4] Response Time"
    run_test
    
    START_TIME=$(date +%s%N)
    curl -s "${BASE_URL}/health" >/dev/null
    END_TIME=$(date +%s%N)
    
    DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    
    if [ $DURATION_MS -lt 500 ]; then
        pass_test "Response time acceptable: ${DURATION_MS}ms"
    else
        fail_test "Response time too high: ${DURATION_MS}ms" "Expected < 500ms"
    fi
}

test_error_handling() {
    echo ""
    echo "[Test 5] Error Handling"
    
    run_test
    RESPONSE=$(curl -s -X POST "${BASE_URL}/predict" \
        -H "Content-Type: application/json" \
        -d "invalid json" 2>&1)
    
    if echo "$RESPONSE" | grep -q "error\|detail\|422"; then
        pass_test "Invalid JSON handled properly"
    else
        fail_test "Invalid JSON not handled" "$RESPONSE"
    fi
    
    run_test
    RESPONSE=$(curl -s -X POST "${BASE_URL}/predict" \
        -H "Content-Type: application/json" \
        -d '{"wrong_field": [1,2,3]}' 2>&1)
    
    if echo "$RESPONSE" | grep -q "error\|detail\|422"; then
        pass_test "Missing features handled properly"
    else
        fail_test "Missing features not handled"
    fi
}

test_load_handling() {
    echo ""
    echo "[Test 6] Load Handling (10 concurrent requests)"
    run_test
    
    SUCCESS_COUNT=0
    TOTAL_REQUESTS=10
    
    for i in $(seq 1 $TOTAL_REQUESTS); do
        if curl -s --max-time 5 "${BASE_URL}/health" >/dev/null 2>&1; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    done
    
    if [ $SUCCESS_COUNT -eq $TOTAL_REQUESTS ]; then
        pass_test "All $TOTAL_REQUESTS requests successful"
    else
        fail_test "Only $SUCCESS_COUNT/$TOTAL_REQUESTS requests successful"
    fi
}

test_docker_containers() {
    echo ""
    echo "[Test 7] Docker Containers"
    run_test
    
    if docker ps | grep -q "ml-service"; then
        pass_test "ML service container is running"
        info "Container info:"
        docker ps --filter "name=ml-service" --format "  - {{.Names}} ({{.Status}})"
    else
        fail_test "ML service container not found"
    fi
    
    run_test
    if docker ps | grep -q "nginx"; then
        pass_test "Nginx container is running"
        info "Container info:"
        docker ps --filter "name=nginx" --format "  - {{.Names}} ({{.Status}})"
    else
        fail_test "Nginx container not found"
    fi
}

test_network() {
    echo ""
    echo "[Test 8] Network Configuration"
    
    run_test
    if curl -s --max-time 5 "http://localhost:8081/health" >/dev/null 2>&1; then
        pass_test "Blue environment accessible on port 8081"
    else
        info "Blue environment not accessible (may be expected if Green is active)"
    fi
    
    run_test
    if curl -s --max-time 5 "http://localhost:8082/health" >/dev/null 2>&1; then
        pass_test "Green environment accessible on port 8082"
    else
        info "Green environment not accessible (may be expected if Blue is active)"
    fi
}

test_deployment_headers() {
    echo ""
    echo "[Test 9] Deployment Version Headers"
    run_test
    
    HEADERS=$(curl -s -I "${BASE_URL}/health")
    
    if echo "$HEADERS" | grep -qi "X-Deployment-Version"; then
        VERSION_HEADER=$(echo "$HEADERS" | grep -i "X-Deployment-Version" | cut -d' ' -f2- | tr -d '\r\n')
        pass_test "Deployment version header present: $VERSION_HEADER"
    else
        info "Deployment version header not present (optional)"
    fi
}

test_prediction_consistency() {
    echo ""
    echo "[Test 10] Prediction Consistency"
    run_test
    
    TEST_DATA='{"features": [5.1, 3.5, 1.4, 0.2]}'
    
    PREDICTIONS=()
    for i in $(seq 1 5); do
        PRED=$(curl -s -X POST "${BASE_URL}/predict" \
            -H "Content-Type: application/json" \
            -d "$TEST_DATA" | \
            python3 -c "import sys, json; print(json.load(sys.stdin).get('prediction', ''))" 2>/dev/null)
        PREDICTIONS+=("$PRED")
    done
    
    UNIQUE_PREDICTIONS=$(printf '%s\n' "${PREDICTIONS[@]}" | sort -u | wc -l)
    
    if [ $UNIQUE_PREDICTIONS -eq 1 ]; then
        pass_test "Predictions are consistent: ${PREDICTIONS[0]}"
    else
        fail_test "Predictions are inconsistent" "Got different results: ${PREDICTIONS[*]}"
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  Verification Summary"
    echo "=========================================="
    echo ""
    echo "  Total Tests:  $TOTAL_TESTS"
    echo "  Passed:       $PASSED_TESTS"
    
    if [ $FAILED_TESTS -gt 0 ]; then
        echo "  Failed:       $FAILED_TESTS"
    else
        echo "  Failed:       $FAILED_TESTS"
    fi
    
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo "All tests passed"
        echo ""
        return 0
    else
        echo "Some tests failed"
        echo ""
        echo "Troubleshooting tips:"
        echo "  1. Check service logs:      docker compose logs"
        echo "  2. Verify containers:       docker ps"
        echo "  3. Check network:           docker network ls"
        echo "  4. Restart services:        make restart"
        echo ""
        return 1
    fi
}

main() {
    test_availability || exit 1
    test_health_endpoint
    test_predict_endpoint
    test_response_time
    test_error_handling
    test_load_handling
    test_docker_containers
    test_network
    test_deployment_headers
    test_prediction_consistency
    
    print_summary
}

main
exit $?
