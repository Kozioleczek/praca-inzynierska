const API_ROOT = import.meta.env.VITE_API_ROOT;

export const useGenerateIso = () => {
  const requestIsoGeneration = async (payload: {
    packages: string[];
    isoUrl: string;
  }): Promise<{ isoName: string }> => {
    const response = await fetch(`${API_ROOT}/generate-iso`, {
      method: "POST",
      body: JSON.stringify(payload),
      headers: {
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      throw new Error("Something went wrong");
    }

    const data: { isoName: string } = await response.json();

    return data;
  };

  const getLogs = async () => {
    const response = await fetch(`${API_ROOT}/logs`);

    if (!response.ok) {
      throw new Error("Something went wrong");
    }

    const data: {
      fileName: string;
      progress: number;
      status: string;
      downloadUrl: string | null;
    }[] = await response.json();

    return data;
  };

  const getProgressForIso = async (isoName: string) => {
    const response = await fetch(`${API_ROOT}/progress/${isoName}`);

    if (!response.ok) {
      throw new Error("Something went wrong");
    }

    const data: { progress: number; status: string } = await response.json();

    return data;
  };

  const downloadIsoUrl = async (isoName: string) => {
    const response = await fetch(`${API_ROOT}/download/${isoName}`);

    if (!response.ok) {
      throw new Error("Something went wrong");
    }

    const data: { downloadUrl: string } = await response.json();

    return data;
  };

  return {
    requestIsoGeneration,
    getProgressForIso,
    downloadIsoUrl,
    getLogs,
  };
};
