#!/bin/bash

BASE_URL="${1:-http://localhost}"

echo "======================================"
echo "ML Service Testing Script"
echo "======================================"
echo ""

test_health() {
    echo "[TEST 1] Testing /health endpoint..."
    RESPONSE=$(curl -s "${BASE_URL}/health")
    
    if echo "$RESPONSE" | grep -q '"status":"ok"'; then
        VERSION=$(echo "$RESPONSE" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        echo "Health check passed"
        echo "  Version: ${VERSION}"
        return 0
    else
        echo "Health check failed"
        echo "  Response: $RESPONSE"
        return 1
    fi
}

test_predict() {
    echo "[TEST 2] Testing /predict endpoint..."
    
    TEST_DATA='{"features": [5.1, 3.5, 1.4, 0.2]}'
    
    RESPONSE=$(curl -s -X POST "${BASE_URL}/predict" \
        -H "Content-Type: application/json" \
        -d "$TEST_DATA")
    
    if echo "$RESPONSE" | grep -q '"prediction"'; then
        PREDICTION=$(echo "$RESPONSE" | grep -o '"prediction":[^,]*' | cut -d':' -f2)
        VERSION=$(echo "$RESPONSE" | grep -o '"model_version":"[^"]*"' | cut -d'"' -f4)
        echo "Prediction successful"
        echo "  Prediction: ${PREDICTION}"
        echo "  Model version: ${VERSION}"
        return 0
    else
        echo "Prediction failed"
        echo "  Response: $RESPONSE"
        return 1
    fi
}

test_load() {
    echo "[TEST 3] Load testing (10 requests)..."
    
    SUCCESS=0
    TOTAL=10
    
    for i in $(seq 1 $TOTAL); do
        RESPONSE=$(curl -s -X POST "${BASE_URL}/predict" \
            -H "Content-Type: application/json" \
            -d '{"features": [5.1, 3.5, 1.4, 0.2]}')
        
        if echo "$RESPONSE" | grep -q '"prediction"'; then
            ((SUCCESS++))
        fi
        
        echo -ne "  Progress: ${SUCCESS}/${TOTAL}\r"
    done
    
    echo ""
    
    if [ $SUCCESS -eq $TOTAL ]; then
        echo "Load test passed: ${SUCCESS}/${TOTAL} successful"
        return 0
    else
        echo "Load test failed: ${SUCCESS}/${TOTAL} successful"
        return 1
    fi
}

test_metrics() {
    echo "[TEST 4] Testing /metrics endpoint..."
    RESPONSE=$(curl -s "${BASE_URL}/metrics")
    
    if echo "$RESPONSE" | grep -q '"model_version"'; then
        echo "Metrics endpoint available"
        echo "  Response: $RESPONSE"
        return 0
    else
        echo "Metrics endpoint not available (optional)"
        return 0
    fi
}

FAILED=0

test_health || ((FAILED++))
echo ""

test_predict || ((FAILED++))
echo ""

test_load || ((FAILED++))
echo ""

test_metrics || ((FAILED++))
echo ""

echo "======================================"
if [ $FAILED -eq 0 ]; then
    echo "All tests passed"
    exit 0
else
    echo "Some tests failed (${FAILED} failures)"
    exit 1
fi
