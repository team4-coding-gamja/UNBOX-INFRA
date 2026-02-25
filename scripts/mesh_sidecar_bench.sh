#!/usr/bin/env bash
set -euo pipefail

# Benchmark goal:
# - Compare sidecar dataplane startup time between Linkerd and Istio
# - Collect resource metrics per trial (app ns, control-plane ns, node)
#
# Requirements:
# - minikube profiles already created:
#   - mesh-bench        (Linkerd installed)
#   - mesh-bench-istio  (Istio installed)
# - kubectl access via minikube kubectl

MINIKUBE_HOME_DEFAULT="/Users/nacgyun/Desktop/Unbox-infra/.minikube"
MINIKUBE_HOME="${MINIKUBE_HOME:-$MINIKUBE_HOME_DEFAULT}"

REPEATS="${REPEATS:-5}"
LINKERD_PROFILE="${LINKERD_PROFILE:-mesh-bench}"
ISTIO_PROFILE="${ISTIO_PROFILE:-mesh-bench-istio}"

RESULT_DIR="${RESULT_DIR:-results}"
mkdir -p "${RESULT_DIR}"
OUT_CSV="${OUT_CSV:-${RESULT_DIR}/mesh_sidecar_bench_$(date +%Y%m%d_%H%M%S).csv}"

NAMESPACE="bench-dp"

kubectl_profile() {
  local profile="$1"
  shift
  MINIKUBE_HOME="${MINIKUBE_HOME}" minikube -p "${profile}" kubectl -- "$@"
}

ensure_profile() {
  local profile="$1"
  MINIKUBE_HOME="${MINIKUBE_HOME}" minikube -p "${profile}" status >/dev/null
}

ensure_metrics_server() {
  local profile="$1"
  MINIKUBE_HOME="${MINIKUBE_HOME}" minikube -p "${profile}" addons enable metrics-server >/dev/null
  kubectl_profile "${profile}" wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=300s >/dev/null
  kubectl_profile "${profile}" top nodes >/dev/null
}

cpu_to_m() {
  local raw="$1"
  if [[ "${raw}" == *m ]]; then
    echo "${raw%m}"
  else
    awk -v v="${raw}" 'BEGIN { printf "%.0f\n", v * 1000 }'
  fi
}

mem_to_mi() {
  local raw="$1"
  if [[ "${raw}" == *Ki ]]; then
    awk -v v="${raw%Ki}" 'BEGIN { printf "%.0f\n", v / 1024 }'
  elif [[ "${raw}" == *Mi ]]; then
    echo "${raw%Mi}"
  elif [[ "${raw}" == *Gi ]]; then
    awk -v v="${raw%Gi}" 'BEGIN { printf "%.0f\n", v * 1024 }'
  else
    # best effort: assume Mi
    echo "${raw}"
  fi
}

sum_top_pods() {
  local profile="$1"
  local ns="$2"
  local cpu_sum=0
  local mem_sum=0
  local pod_count=0

  while read -r line; do
    [[ -z "${line}" ]] && continue
    local cpu_raw mem_raw
    cpu_raw="$(awk '{print $2}' <<<"${line}")"
    mem_raw="$(awk '{print $3}' <<<"${line}")"
    cpu_sum=$((cpu_sum + $(cpu_to_m "${cpu_raw}")))
    mem_sum=$((mem_sum + $(mem_to_mi "${mem_raw}")))
    pod_count=$((pod_count + 1))
  done < <(kubectl_profile "${profile}" top pods -n "${ns}" --no-headers 2>/dev/null || true)

  echo "${cpu_sum},${mem_sum},${pod_count}"
}

sum_top_nodes() {
  local profile="$1"
  local cpu_sum=0
  local mem_sum=0

  while read -r line; do
    [[ -z "${line}" ]] && continue
    local cpu_raw mem_raw
    cpu_raw="$(awk '{print $2}' <<<"${line}")"
    mem_raw="$(awk '{print $4}' <<<"${line}")"
    cpu_sum=$((cpu_sum + $(cpu_to_m "${cpu_raw}")))
    mem_sum=$((mem_sum + $(mem_to_mi "${mem_raw}")))
  done < <(kubectl_profile "${profile}" top nodes --no-headers 2>/dev/null || true)

  echo "${cpu_sum},${mem_sum}"
}

apply_bench_workload() {
  local profile="$1"
  local mesh="$2"

  kubectl_profile "${profile}" delete ns "${NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null
  kubectl_profile "${profile}" create ns "${NAMESPACE}" >/dev/null

  if [[ "${mesh}" == "linkerd" ]]; then
    kubectl_profile "${profile}" annotate ns "${NAMESPACE}" linkerd.io/inject=enabled --overwrite >/dev/null
    kubectl_profile "${profile}" label ns "${NAMESPACE}" istio-injection- >/dev/null 2>&1 || true
  else
    kubectl_profile "${profile}" label ns "${NAMESPACE}" istio-injection=enabled --overwrite >/dev/null
    kubectl_profile "${profile}" annotate ns "${NAMESPACE}" linkerd.io/inject- >/dev/null 2>&1 || true
  fi

  cat <<'YAML' | kubectl_profile "${profile}" apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: bench-dp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
      bench: dp
  template:
    metadata:
      labels:
        app: app1
        bench: dp
      annotations:
        sidecar.istio.io/inject: "true"
        linkerd.io/inject: enabled
    spec:
      containers:
      - name: app
        image: nginx:1.27
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: bench-dp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
      bench: dp
  template:
    metadata:
      labels:
        app: app2
        bench: dp
      annotations:
        sidecar.istio.io/inject: "true"
        linkerd.io/inject: enabled
    spec:
      containers:
      - name: app
        image: nginx:1.27
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app3
  namespace: bench-dp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app3
      bench: dp
  template:
    metadata:
      labels:
        app: app3
        bench: dp
      annotations:
        sidecar.istio.io/inject: "true"
        linkerd.io/inject: enabled
    spec:
      containers:
      - name: app
        image: nginx:1.27
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app4
  namespace: bench-dp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app4
      bench: dp
  template:
    metadata:
      labels:
        app: app4
        bench: dp
      annotations:
        sidecar.istio.io/inject: "true"
        linkerd.io/inject: enabled
    spec:
      containers:
      - name: app
        image: nginx:1.27
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app5
  namespace: bench-dp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app5
      bench: dp
  template:
    metadata:
      labels:
        app: app5
        bench: dp
      annotations:
        sidecar.istio.io/inject: "true"
        linkerd.io/inject: enabled
    spec:
      containers:
      - name: app
        image: nginx:1.27
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
YAML
}

wait_bench_ready() {
  local profile="$1"
  kubectl_profile "${profile}" wait --for=condition=Available deployment --all -n "${NAMESPACE}" --timeout=900s >/dev/null
  kubectl_profile "${profile}" wait --for=condition=Ready pod -l bench=dp -n "${NAMESPACE}" --timeout=900s >/dev/null
}

verify_sidecar() {
  local profile="$1"
  local mesh="$2"
  local expected
  if [[ "${mesh}" == "linkerd" ]]; then
    expected="linkerd-proxy"
  else
    expected="istio-proxy"
  fi
  local containers
  containers="$(kubectl_profile "${profile}" get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}')"
  grep -q "${expected}" <<<"${containers}"
}

run_trials() {
  local mesh="$1"
  local profile="$2"
  local control_ns="$3"

  echo "== ${mesh} (${profile}) =="
  ensure_profile "${profile}"
  ensure_metrics_server "${profile}"

  local i
  for ((i=1; i<=REPEATS; i++)); do
    local start end elapsed
    local app_metrics cp_metrics node_metrics
    local app_cpu app_mem app_pods
    local cp_cpu cp_mem cp_pods
    local node_cpu node_mem

    if ! start="$(date +%s)"; then
      echo "trial=${i} failed to get start timestamp"
      continue
    fi
    if ! apply_bench_workload "${profile}" "${mesh}"; then
      echo "trial=${i} workload apply failed"
      continue
    fi
    if ! wait_bench_ready "${profile}"; then
      echo "trial=${i} readiness wait failed"
      continue
    fi
    if ! verify_sidecar "${profile}" "${mesh}"; then
      echo "trial=${i} sidecar verification failed"
      kubectl_profile "${profile}" get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[*].name}{"\n"}{end}' || true
      continue
    fi
    if ! end="$(date +%s)"; then
      echo "trial=${i} failed to get end timestamp"
      continue
    fi
    elapsed=$((end - start))

    # Give metrics-server one scrape window so top is less likely to be empty.
    sleep 15

    app_metrics="$(sum_top_pods "${profile}" "${NAMESPACE}")"
    cp_metrics="$(sum_top_pods "${profile}" "${control_ns}")"
    node_metrics="$(sum_top_nodes "${profile}")"

    IFS=',' read -r app_cpu app_mem app_pods <<<"${app_metrics}"
    IFS=',' read -r cp_cpu cp_mem cp_pods <<<"${cp_metrics}"
    IFS=',' read -r node_cpu node_mem <<<"${node_metrics}"

    echo "${mesh},${i},${elapsed},${app_cpu},${app_mem},${app_pods},${cp_cpu},${cp_mem},${cp_pods},${node_cpu},${node_mem}" >> "${OUT_CSV}"
    echo "trial=${i} startup=${elapsed}s app=${app_cpu}m/${app_mem}Mi cp=${cp_cpu}m/${cp_mem}Mi node=${node_cpu}m/${node_mem}Mi"
  done
}

print_summary() {
  local mesh="$1"
  local vals=()
  while IFS= read -r v; do
    vals+=("${v}")
  done < <(awk -F, -v m="${mesh}" '$1==m {print $3}' "${OUT_CSV}" | sort -n)
  local count="${#vals[@]}"
  if [[ "${count}" -eq 0 ]]; then
    echo "${mesh}: no data"
    return
  fi
  local sum=0
  local v
  for v in "${vals[@]}"; do
    sum=$((sum + v))
  done
  local avg
  avg="$(awk -v s="${sum}" -v c="${count}" 'BEGIN { printf "%.2f", s/c }')"

  local median
  if (( count % 2 == 1 )); then
    median="${vals[$((count/2))]}"
  else
    local a b
    a="${vals[$((count/2 - 1))]}"
    b="${vals[$((count/2))]}"
    median="$(awk -v x="${a}" -v y="${b}" 'BEGIN { printf "%.2f", (x+y)/2 }')"
  fi

  local app_cpu_avg app_mem_avg cp_cpu_avg cp_mem_avg node_cpu_avg node_mem_avg
  app_cpu_avg="$(awk -F, -v m="${mesh}" '$1==m {s+=$4; c++} END {if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"
  app_mem_avg="$(awk -F, -v m="${mesh}" '$1==m {s+=$5; c++} END {if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"
  cp_cpu_avg="$(awk -F, -v m="${mesh}" '$1==m {s+=$7; c++} END {if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"
  cp_mem_avg="$(awk -F, -v m="${mesh}" '$1==m {s+=$8; c++} END {if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"
  node_cpu_avg="$(awk -F, -v m="${mesh}" '$1==m {s+=$10; c++} END {if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"
  node_mem_avg="$(awk -F, -v m="${mesh}" '$1==m {s+=$11; c++} END {if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"

  echo
  echo "[${mesh}]"
  echo "startup_seconds avg=${avg}, median=${median}"
  echo "app_ns avg_cpu=${app_cpu_avg}m avg_mem=${app_mem_avg}Mi"
  echo "control_ns avg_cpu=${cp_cpu_avg}m avg_mem=${cp_mem_avg}Mi"
  echo "node_total avg_cpu=${node_cpu_avg}m avg_mem=${node_mem_avg}Mi"
}

echo "mesh,trial,startup_seconds,app_ns_cpu_m,app_ns_mem_mi,app_ns_pods,control_ns_cpu_m,control_ns_mem_mi,control_ns_pods,node_cpu_m,node_mem_mi" > "${OUT_CSV}"

run_trials "linkerd" "${LINKERD_PROFILE}" "linkerd"
run_trials "istio" "${ISTIO_PROFILE}" "istio-system"

print_summary "linkerd"
print_summary "istio"

echo
echo "CSV saved: ${OUT_CSV}"
