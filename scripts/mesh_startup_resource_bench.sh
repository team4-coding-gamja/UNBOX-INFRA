#!/usr/bin/env bash
set -euo pipefail

# High-frequency startup resource benchmark for Linkerd vs Istio sidecars.
# Uses kubelet summary API instead of kubectl top for finer startup sampling.
#
# Outputs:
# - CSV per trial
# - Summary (avg/median ready time, avg sidecar cpu core-seconds, avg sidecar mem peak Mi)

MINIKUBE_HOME="${MINIKUBE_HOME:-/Users/nacgyun/Desktop/Unbox-infra/.minikube}"
LINKERD_PROFILE="${LINKERD_PROFILE:-mesh-bench}"
ISTIO_PROFILE="${ISTIO_PROFILE:-mesh-bench-istio}"
REPEATS="${REPEATS:-5}"
NAMESPACE="${NAMESPACE:-bench-startup}"
SAMPLE_INTERVAL="${SAMPLE_INTERVAL:-2}" # seconds
RESULT_DIR="${RESULT_DIR:-results}"
mkdir -p "${RESULT_DIR}"
OUT_CSV="${OUT_CSV:-${RESULT_DIR}/mesh_startup_resource_bench_$(date +%Y%m%d_%H%M%S).csv}"

kubectl_p() {
  local profile="$1"
  shift
  MINIKUBE_HOME="${MINIKUBE_HOME}" minikube -p "${profile}" kubectl -- "$@"
}

node_name() {
  local profile="$1"
  kubectl_p "${profile}" get nodes -o jsonpath='{.items[0].metadata.name}'
}

setup_ns() {
  local profile="$1"
  local mesh="$2"
  kubectl_p "${profile}" delete ns "${NAMESPACE}" --ignore-not-found=true --wait=true >/dev/null 2>&1 || true
  kubectl_p "${profile}" create ns "${NAMESPACE}" >/dev/null
  if [[ "${mesh}" == "linkerd" ]]; then
    kubectl_p "${profile}" annotate ns "${NAMESPACE}" linkerd.io/inject=enabled --overwrite >/dev/null
    kubectl_p "${profile}" label ns "${NAMESPACE}" istio-injection- >/dev/null 2>&1 || true
    kubectl_p "${profile}" label ns "${NAMESPACE}" istio.io/rev- >/dev/null 2>&1 || true
  else
    kubectl_p "${profile}" label ns "${NAMESPACE}" istio-injection=enabled --overwrite >/dev/null
    kubectl_p "${profile}" annotate ns "${NAMESPACE}" linkerd.io/inject- >/dev/null 2>&1 || true
  fi
}

apply_workload() {
  local profile="$1"
  local mesh="$2"
  local ann=""
  if [[ "${mesh}" == "istio" ]]; then
    ann=$'        sidecar.istio.io/inject: "true"'
  else
    ann='        linkerd.io/inject: enabled'
  fi

  cat <<YAML | kubectl_p "${profile}" apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector: { matchLabels: { app: app1, bench: startup } }
  template:
    metadata:
      labels: { app: app1, bench: startup }
      annotations:
${ann}
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
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector: { matchLabels: { app: app2, bench: startup } }
  template:
    metadata:
      labels: { app: app2, bench: startup }
      annotations:
${ann}
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
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector: { matchLabels: { app: app3, bench: startup } }
  template:
    metadata:
      labels: { app: app3, bench: startup }
      annotations:
${ann}
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
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector: { matchLabels: { app: app4, bench: startup } }
  template:
    metadata:
      labels: { app: app4, bench: startup }
      annotations:
${ann}
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
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector: { matchLabels: { app: app5, bench: startup } }
  template:
    metadata:
      labels: { app: app5, bench: startup }
      annotations:
${ann}
    spec:
      containers:
      - name: app
        image: nginx:1.27
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
YAML
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
  kubectl_p "${profile}" wait --for=condition=Ready pod -l bench=startup -n "${NAMESPACE}" --timeout=600s >/dev/null
  local c
  c="$(kubectl_p "${profile}" get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep -c "${expected}" || true)"
  [[ "${c}" -ge 5 ]]
}

sample_summary_once() {
  local profile="$1"
  local node="$2"
  local sidecar_regex="$3"
  local raw
  raw="$(kubectl_p "${profile}" get --raw "/api/v1/nodes/${node}/proxy/stats/summary")"

  # Output: sidecar_cpu_ns,sidecar_mem_bytes,app_cpu_ns,app_mem_bytes,sidecar_count,app_count
  jq -r --arg ns "${NAMESPACE}" --arg srx "${sidecar_regex}" '
    def sumcpu(arr): (arr | map(.cpu.usageCoreNanoSeconds // 0) | add // 0);
    def summem(arr): (arr | map(.memory.workingSetBytes // 0) | add // 0);
    [
      .pods[] | select(.podRef.namespace==$ns) | .containers[]
    ] as $all
    |
    ($all | map(select(.name|test($srx)))) as $side
    |
    ($all | map(select(.name=="app"))) as $app
    |
    [sumcpu($side), summem($side), sumcpu($app), summem($app), ($side|length), ($app|length)]
    | @csv
  ' <<<"${raw}" | tr -d '"'
}

run_trial() {
  local mesh="$1"
  local profile="$2"
  local trial="$3"
  local sidecar_regex
  if [[ "${mesh}" == "linkerd" ]]; then
    sidecar_regex='^linkerd-proxy$'
  else
    sidecar_regex='^istio-proxy$'
  fi

  setup_ns "${profile}" "${mesh}"
  local node
  node="$(node_name "${profile}")"

  apply_workload "${profile}" "${mesh}"
  local t0
  t0="$(date +%s)"

  local sample_file
  sample_file="$(mktemp)"

  (
    while true; do
      local ts
      ts="$(date +%s)"
      local row
      row="$(sample_summary_once "${profile}" "${node}" "${sidecar_regex}" || echo "0,0,0,0,0,0")"
      echo "${ts},${row}" >> "${sample_file}"
      sleep "${SAMPLE_INTERVAL}"
    done
  ) &
  local sampler_pid=$!

  local ready_ok=1
  if ! kubectl_p "${profile}" wait --for=condition=Available deployment --all -n "${NAMESPACE}" --timeout=900s >/dev/null 2>&1; then
    ready_ok=0
  fi
  local t1
  t1="$(date +%s)"

  # Give a short settling sample after ready
  sleep 2
  kill "${sampler_pid}" >/dev/null 2>&1 || true
  wait "${sampler_pid}" 2>/dev/null || true

  local ready_seconds=$((t1 - t0))

  # Sidecar verification after sampling to avoid blocking trial output
  local sidecar_ok=1
  if ! verify_sidecar "${profile}" "${mesh}"; then
    sidecar_ok=0
  fi

  # Compute cpu core-seconds and memory peak from sample file.
  local side_cpu_start side_cpu_end app_cpu_start app_cpu_end
  local side_mem_peak app_mem_peak side_count_peak app_count_peak

  side_cpu_start="$(awk -F, 'NR==1{print $2}' "${sample_file}")"
  side_cpu_end="$(awk -F, 'END{print $2}' "${sample_file}")"
  app_cpu_start="$(awk -F, 'NR==1{print $4}' "${sample_file}")"
  app_cpu_end="$(awk -F, 'END{print $4}' "${sample_file}")"

  side_mem_peak="$(awk -F, 'BEGIN{m=0} {if($3>m)m=$3} END{print m}' "${sample_file}")"
  app_mem_peak="$(awk -F, 'BEGIN{m=0} {if($5>m)m=$5} END{print m}' "${sample_file}")"
  side_count_peak="$(awk -F, 'BEGIN{m=0} {if($6>m)m=$6} END{print m}' "${sample_file}")"
  app_count_peak="$(awk -F, 'BEGIN{m=0} {if($7>m)m=$7} END{print m}' "${sample_file}")"

  local side_cpu_core_seconds app_cpu_core_seconds
  side_cpu_core_seconds="$(awk -v a="${side_cpu_start}" -v b="${side_cpu_end}" 'BEGIN{printf "%.6f", (b-a)/1000000000}')"
  app_cpu_core_seconds="$(awk -v a="${app_cpu_start}" -v b="${app_cpu_end}" 'BEGIN{printf "%.6f", (b-a)/1000000000}')"
  local side_mem_peak_mi app_mem_peak_mi
  side_mem_peak_mi="$(awk -v b="${side_mem_peak}" 'BEGIN{printf "%.2f", b/1024/1024}')"
  app_mem_peak_mi="$(awk -v b="${app_mem_peak}" 'BEGIN{printf "%.2f", b/1024/1024}')"

  echo "${mesh},${trial},${ready_seconds},${ready_ok},${sidecar_ok},${side_cpu_core_seconds},${side_mem_peak_mi},${side_count_peak},${app_cpu_core_seconds},${app_mem_peak_mi},${app_count_peak}" >> "${OUT_CSV}"
  echo "${mesh} trial=${trial} ready=${ready_seconds}s sidecar_cpu=${side_cpu_core_seconds} core-s sidecar_mem_peak=${side_mem_peak_mi}Mi sidecars=${side_count_peak}"

  rm -f "${sample_file}"
}

print_summary() {
  local mesh="$1"
  local rows
  rows="$(awk -F, -v m="${mesh}" '$1==m && $4==1 && $5==1' "${OUT_CSV}" | wc -l | tr -d ' ')"
  if [[ "${rows}" -eq 0 ]]; then
    echo "[${mesh}] no valid rows"
    return
  fi
  local ready_avg ready_med side_cpu_avg side_mem_avg
  ready_avg="$(awk -F, -v m="${mesh}" '$1==m && $4==1 && $5==1 {s+=$3;c++} END{if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"
  side_cpu_avg="$(awk -F, -v m="${mesh}" '$1==m && $4==1 && $5==1 {s+=$6;c++} END{if(c) printf "%.4f", s/c; else print "0"}' "${OUT_CSV}")"
  side_mem_avg="$(awk -F, -v m="${mesh}" '$1==m && $4==1 && $5==1 {s+=$7;c++} END{if(c) printf "%.2f", s/c; else print "0"}' "${OUT_CSV}")"

  ready_med="$(
    awk -F, -v m="${mesh}" '$1==m && $4==1 && $5==1 {print $3}' "${OUT_CSV}" | sort -n | awk '
      {a[NR]=$1}
      END{
        if(NR==0){print "0"; exit}
        if(NR%2==1){print a[(NR+1)/2]}
        else{printf "%.2f", (a[NR/2]+a[NR/2+1])/2}
      }'
  )"

  echo "[${mesh}] ready_avg=${ready_avg}s ready_median=${ready_med}s sidecar_cpu_avg=${side_cpu_avg} core-s sidecar_mem_peak_avg=${side_mem_avg}Mi"
}

echo "mesh,trial,ready_seconds,ready_ok,sidecar_ok,sidecar_cpu_core_seconds,sidecar_mem_peak_mi,sidecar_count_peak,app_cpu_core_seconds,app_mem_peak_mi,app_count_peak" > "${OUT_CSV}"

for i in $(seq 1 "${REPEATS}"); do
  run_trial "linkerd" "${LINKERD_PROFILE}" "${i}"
done

for i in $(seq 1 "${REPEATS}"); do
  run_trial "istio" "${ISTIO_PROFILE}" "${i}"
done

echo
print_summary "linkerd"
print_summary "istio"
echo "CSV saved: ${OUT_CSV}"
