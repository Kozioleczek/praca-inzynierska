<script setup lang="ts">
import { useGenerateIso } from "@/composables/useGenerateIso";
import { Check, Circle, Dot } from "lucide-vue-next";

import {
  Stepper,
  StepperItem,
  StepperSeparator,
  StepperTitle,
} from "@/components/ui/stepper";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";
import { useForm } from "vee-validate";
import { toTypedSchema } from "@vee-validate/zod";
import * as z from "zod";
import {
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { onBeforeUnmount, onMounted, ref } from "vue";
import { Button, buttonVariants } from "@/components/ui/button";
import {
  TagsInput,
  TagsInputItem,
  TagsInputItemDelete,
  TagsInputItemText,
  TagsInputInput,
} from "@/components/ui/tags-input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

const formSchema = toTypedSchema(
  z.object({
    packages: z.string().array().nonempty(),
    isoUrl: z
      .string()
      .refine(
        (value) =>
          /^http:\/\/releases\.ubuntu\.com\/20\.04\/.+\.iso$/.test(value ?? ""),
        "Link do obrazu powinien pochodzić z http://releases.ubuntu.com/ ex. http://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso"
      ),
  })
);

const { defineField, handleSubmit, handleReset } = useForm({
  initialValues: {
    isoUrl: undefined,
    packages: ["htop"],
  },
  validationSchema: formSchema,
});

const stepIndex = ref(1);

const steps = [
  {
    step: 1,
    title: "Szczegóły ISO",
  },
  {
    step: 2,
    title: "Generowanie ISO",
  },
  {
    step: 3,
    title: "Pobierz ISO",
  },
];

const { requestIsoGeneration, downloadIsoUrl, getProgressForIso, getLogs } =
  useGenerateIso();

const generatedIsoName = ref<string | null>(null);

const generationProgress = ref<{ progress: number; status: string } | null>(
  null
);

const downloadUrlResponse = ref<string | null>(null);

let progressPullingInterval: NodeJS.Timeout | null = null;

const pullProgressForIso = async () => {
  if (!generatedIsoName.value) return;

  const response = await getProgressForIso(generatedIsoName.value);

  generationProgress.value = response;

  if (response.progress === 100) {
    stopProgressInterval();

    const { downloadUrl } = await downloadIsoUrl(generatedIsoName.value);

    downloadUrlResponse.value = downloadUrl;

    stepIndex.value = 3;

    await loadLogs();
  }
};

const startProgressInterval = () => {
  progressPullingInterval = setInterval(() => {
    pullProgressForIso();
  }, 5000);
};

const stopProgressInterval = () => {
  if (progressPullingInterval) {
    clearInterval(progressPullingInterval);
    progressPullingInterval = null;
  }
};

const onSubmit = handleSubmit(async (values) => {
  const { isoName } = await requestIsoGeneration(values);
  generatedIsoName.value = isoName;
  stepIndex.value = 2;
  startProgressInterval();
});

onBeforeUnmount(() => {
  stopProgressInterval();
});

const [selectedPackages] = defineField("packages");

const resetAll = () => {
  stepIndex.value = 1;
  generatedIsoName.value = null;
  generationProgress.value = null;
  downloadUrlResponse.value = null;

  handleReset();
};

const logs = ref<
  {
    fileName: string;
    progress: number;
    status: string;
    downloadUrl: string | null;
  }[]
>([]);

const loadLogs = async () => {
  const response = await getLogs();

  logs.value = [...response];
};

onMounted(async () => {
  await loadLogs();
});
</script>

<template>
  <div class="w-full lg:w-auto lg:max-w-5xl mx-auto px-4 xl:px-0 py-10">
    <div class="flex flex-col mb-6">
      <h1 class="text-lg font-semibold mb-2">Kreator obrazów ISO</h1>

      <p>Aby utworzyć obraz ISO wypełnij poniszy formularz:</p>
    </div>

    <div class="border rounded-md p-4 mb-10">
      <Stepper v-model="stepIndex" class="flex w-full items-start gap-2 mb-3">
        <StepperItem
          v-for="step in steps"
          :step="step.step"
          :key="step.step"
          v-slot="{ state }"
          class="relative flex w-full flex-col items-center justify-center"
        >
          <StepperSeparator
            v-if="step.step !== steps[steps.length - 1].step"
            class="absolute left-[calc(50%+20px)] right-[calc(-50%+10px)] top-5 block h-0.5 shrink-0 rounded-full bg-muted group-data-[state=completed]:bg-primary"
          />

          <div>
            <Button
              :variant="
                state === 'completed' || state === 'active'
                  ? 'default'
                  : 'outline'
              "
              size="icon"
              class="z-10 rounded-full shrink-0"
              :class="[
                state === 'active' &&
                  'ring-2 ring-ring ring-offset-2 ring-offset-background',
              ]"
            >
              <Check v-if="state === 'completed'" class="size-5" />
              <Circle v-if="state === 'active'" />
              <Dot v-if="state === 'inactive'" />
            </Button>
          </div>

          <div class="mt-5 flex flex-col items-center text-center">
            <StepperTitle
              :class="[state === 'active' && 'text-primary']"
              class="text-sm font-semibold transition lg:text-base"
            >
              {{ step.title }}
            </StepperTitle>
          </div>
        </StepperItem>
      </Stepper>

      <template v-if="stepIndex === 1">
        <form @submit="onSubmit" class="flex flex-col gap-4">
          <FormField v-slot="{ componentField }" name="isoUrl">
            <FormItem>
              <FormLabel>Link do obrazu ISO</FormLabel>
              <FormControl>
                <Input
                  type="text"
                  placeholder="http://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso"
                  v-bind="componentField"
                />
              </FormControl>
              <FormDescription> To będzie twój obraz bazowy </FormDescription>
              <FormMessage />
            </FormItem>
          </FormField>
          <FormField name="packages">
            <FormItem>
              <FormLabel>Wybrane pakiety dodatkowe</FormLabel>

              <FormControl>
                <TagsInput v-model="selectedPackages">
                  <TagsInputItem
                    v-for="item in selectedPackages"
                    :key="item"
                    :value="item"
                  >
                    <TagsInputItemText />
                    <TagsInputItemDelete />
                  </TagsInputItem>

                  <TagsInputInput
                    placeholder="Wpisz nazwę dodatkowe pakietu i naciśnij ENTER..."
                  />
                </TagsInput>
              </FormControl>
              <FormMessage />
            </FormItem>
          </FormField>

          <Button type="submit" class="w-fit"> Wygeneruj obraz ISO </Button>
        </form>
      </template>
      <template v-else-if="stepIndex === 2">
        <div class="flex justify-center items-center gap-4 flex-col py-10">
          <div class="text-center">
            <p class="text-xl font-semibold">Trwa generowanie obrazu ISO:</p>

            <p class="font-mono">{{ generatedIsoName }}</p>
          </div>

          <div class="w-full flex flex-col gap-2 items-center">
            <Progress
              :model-value="generationProgress?.progress"
              class="animate-pulse"
            />
            <p class="text-sm font-mono">
              Postęp: {{ generationProgress?.progress }}%
            </p>
          </div>

          <p class="font-mono">Status: {{ generationProgress?.status }}</p>
        </div>
      </template>
      <template v-else-if="stepIndex === 3">
        <div class="flex justify-center items-center gap-4 flex-col py-10">
          <div class="text-center">
            <p class="text-xl font-semibold">Obraz ISO został wygenerowany!</p>

            <p class="font-mono">{{ generatedIsoName }}</p>
          </div>

          <a
            v-if="downloadUrlResponse"
            :href="downloadUrlResponse"
            download
            :class="
              buttonVariants({
                variant: 'default',
                size: 'lg',
              })
            "
          >
            Pobierz ISO
          </a>

          <Button @click="resetAll" variant="outline"
            >Wygeneruj kolejny obraz</Button
          >
        </div>
      </template>
    </div>

    <div>
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-lg font-semibold mb-2">Archiwum obrazów</h2>

        <Button @click="loadLogs" variant="outline">Przeładuj dane</Button>
      </div>
      <Table v-if="logs">
        <TableHeader>
          <TableRow>
            <TableHead class="w-[100px]"> Nazwa </TableHead>
            <TableHead>Status</TableHead>
            <TableHead>Postęp</TableHead>
            <TableHead class="text-right"> Link do pobrania </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-for="(log, index) in logs" :key="index">
            <TableCell class="font-medium">
              {{ log.fileName }}
            </TableCell>
            <TableCell>
              {{ log.status }}
            </TableCell>
            <TableCell>
              <Progress :model-value="log?.progress" />
              <p class="text-xs text-mono">{{ log?.progress || 0 }} %</p>
            </TableCell>
            <TableCell class="text-right">
              <a
                :href="log.downloadUrl || '#'"
                download
                :disabled="!log.downloadUrl"
                :class="buttonVariants({ variant: 'default' })"
                >Pobierz</a
              >
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
      <div v-else>
        Brak archiwalnych obrazów. Po wygenerowaniu obrazu zobaczysz go tutaj.
      </div>
    </div>
  </div>
</template>
